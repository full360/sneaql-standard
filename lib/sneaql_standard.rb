require 'sneaql'
require 'jdbc_helpers'
require 'dotenv'
require 'thread'

require_relative 'sneaql_standard_lib/logging.rb'
require_relative 'sneaql_standard_lib/parallelize.rb'
require_relative 'sneaql_standard_lib/jdbc_drivers.rb'

Dotenv.load

module Sneaql
  # top level class for interacting with sneaql standard
  class SneaqlStandard
    # exposed for unit testing
    attr_reader :params
    attr_accessor :q

    # runs all transforms
    def run
      set_params
      configure_jdbc_driver
      build_transform_queue
      run_transforms
    end

    # creates database objects
    # @param [String] transform_table_name if provided will override sneaql.transforms
    def create_db_objects(transform_table_name = nil)
      set_params
      configure_jdbc_driver
      create_transforms_table(transform_table_name)
    end

    # creates transform_table
    # @param [String] transform_table_name if provided will override sneaql.transforms
    def create_transforms_table(transform_table_name = nil)
      transform_table_name = 'sneaql.transforms' unless transform_table_name
      connection = create_connection
      db_manager = Sneaql::Core.find_class(
        :database,
        @params[:database]
      ).new

      if transform_table_name =~ /\w+\.\w+/
        # indicates schema qualfied object
        # make sure db supports schemas
        unless ['sqlite'].include?(@params[:database])
          # create schema if needed
          JDBCHelpers::Execute.new(
            connection,
            "create schema if not exists #{transform_table_name.match(/^\w+/)};"
          )
        end
      end

      creator = Sneaql::Standard::DBObjectCreator.new(
        connection,
        db_manager,
        logger
      )
      creator.create_transforms_table(transform_table_name)

    ensure
      connection.close
    end

    # processes environment variables
    def set_params
      @params = {}

      # each of these lil' hashes represents an env_var
      # that is required, as well as an optional
      # regex validation
      [
        {
          var: 'SNEAQL_JDBC_URL',
          sym: :jdbc_url,
          validation: /^jdbc\:.+/i
        },
        {
          var: 'SNEAQL_DB_USER',
          sym: :db_user
        },
        {
          var: 'SNEAQL_DB_PASS',
          sym: :db_pass
        },
        {
          var: 'SNEAQL_JDBC_DRIVER_JAR',
          sym: :jdbc_driver_jar,
          validation: /^(http\:\/\/.+|file\:\/\/.+|s3\:\/\/.+)/i
        },
        {
          var: 'SNEAQL_JDBC_DRIVER_CLASS',
          sym: :jdbc_driver_class
        }
      ].each do |env_var|
        raise "required environment variable #{env_var[:var]} not provided" unless ENV[env_var[:var]]
        # assign the value of the env_var to the symbol key of @params
        @params[env_var[:sym]] = ENV[env_var[:var]]

        # validate if a validation is provided
        if env_var[:validation]
          unless @params[env_var[:sym]] =~ (env_var[:validation])
            raise "required environment variable #{env_var[:var]} looks invalid"
          end
        end
      end

      # optional env vars are iterated in a similar manner
      # but instead of validation they have a default
      [
        {
          var: 'SNEAQL_JDBC_DRIVER_JAR_MD5',
          sym: :jdbc_driver_jar_md5,
          default: nil
        },
        {
          var: 'SNEAQL_METADATA_MANAGER_TYPE',
          sym: :step_metadata_manager_type,
          default: 'transform_steps_table'
        },
        {
          var: 'SNEAQL_REPO_BASE_DIR',
          sym: :repo_base_dir,
          default: '/tmp/sneaql/repos'
        },
        {
          var: 'SNEAQL_TRANSFORM_CONCURRENCY',
          sym: :concurrency,
          default: 1
        },
        {
          var: 'SNEAQL_TRANSFORM_TABLE_NAME',
          sym: :transform_table_name,
          default: 'sneaql.transforms'
        }
      ].each do |env_var|
        @params[env_var[:sym]] = ENV[env_var[:var]] ? ENV[env_var[:var]] : env_var[:default]
      end

      # numeric parameter provided by env var should be casted
      @params[:concurrency] = @params[:concurrency].to_i

      # determine database type based jdbc url
      # while technically any jdbc driver should work
      # with sneaql, the database type allows for better
      # handling of transactions, boolean, etc.
      @params[:database] = Sneaql::Core.database_type(@params[:jdbc_url])
    rescue => e
      logger.error(e.message)
      raise e
    end

    # creates a threadsafe queue with all active transforms
    def build_transform_queue
      # creates a queue to hold all the transform parameter hashes
      @q = Queue.new

      transforms = sneaql_transforms
      logger.info("#{transforms.length} transforms found in database...")

      # push transforms on to queue
      transforms.each do |t|
        tmp = {}.merge(@params)
        tmp[:transform_name] = t['transform_name']

        # repo must be http or git https
        raise 'malformed transform definition' unless t['sql_repository'] =~ /^http.*/i

        tmp[:repo_url] = t['sql_repository']

        # determine repo type based upon the the presence or absence of branch
        # this comes from sql which is why the casting and strip
        if t['sql_repository_branch'].to_s.strip == ''
          tmp[:repo_type] = 'http'
        else
          tmp[:repo_type] = 'git'
          tmp[:sql_repository_branch] = t['sql_repository_branch']
        end

        tmp[:compression] = 'zip' if tmp[:repo_url] =~ /.*\.zip$/

        # only step manager option
        tmp[:step_metadata_manager_type] = 'local_file'

        # must be sneaql.json in the base of the sneaql repo
        tmp[:step_metadata_file_path] = "#{@params[:repo_base_dir]}/#{tmp[:transform_name]}/sneaql.json"

        @q.push tmp
      end
    rescue => e
      logger.error(e.message)
      e.backtrace.each { |b| logger.error(b) }
    end

    # returns an array of hashes representing the active
    # transforms stored in the database transforms table.
    # @return [Array<Hash>]
    def sneaql_transforms
      # configure driver and db manager
      configure_jdbc_driver
      db_manager = Sneaql::Core.find_class(
        :database,
        @params[:database]
      ).new

      # connect and retrieve transform list
      connection = create_connection

      # fetch an array of active transforms
      transforms = JDBCHelpers::QueryResultsToArray.new(
        connection,
        %(select
            transform_name
            ,sql_repository
            ,sql_repository_branch
          from
            #{@params[:transform_table_name]}
          where
            is_active = #{db_manager.has_boolean ? 'true' : 1}
          order by
            transform_name;),
        logger
      ).results
      connection.close
      return transforms
    ensure
      connection.close if connection
    end

    # perform concurrent transform run
    def run_transforms
      # instantiate parallelize
      ParallelizeSneaqlTransforms.new(
        @q,
        @params[:concurrency],
        logger
      )
    end

    # creates a jdbc connection based upon
    # current driver context
    # @return [JDBCHelpers::ConnectionFactory.connection]
    def create_connection
      JDBCHelpers::ConnectionFactory.new(
        @params[:jdbc_url],
        @params[:db_user],
        @params[:db_pass],
        logger
      ).connection
    end

    # creates a database manager
    # @return [Class]
    def create_db_manager
      Sneaql::Core.find_class(
        :database,
        @params[:database]
      ).new
    end

    # configures the jdbc driver into the current context
    def configure_jdbc_driver
      j = Sneaql::JDBCDriverHandler.new(@params)
      j.confirm_jdbc_driver
      j.require_jdbc_driver
    end
  end
end
