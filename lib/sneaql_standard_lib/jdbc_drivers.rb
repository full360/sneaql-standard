require 'digest'
require 'open-uri'
require 'aws-sdk'

module Sneaql
  # idempotent handling for jdbc driver
  class JDBCDriverHandler
    # exposed for unit tests
    attr_accessor :confirmed_path
    attr_accessor :target_path

    # pulls down the jdbc driver and loads it
    # param [Hash] params parameter hash
    def initialize(params)
      @params = params
    end

    # driver info must be provided
    # jar file should be one of the following:
    #   http store http://path/to/jarfile.jar
    #   inside container file://path/to/jarfile.jar
    #   s3 bucket s3://path/to/jarfile.jar requires aws credentials to be provided
    # this method confirms the existence of the jdbc driver jar file
    # if the file exists, no action is taken.  if file does not exist
    # it is downloaded from the source location, either http or s3.
    def confirm_jdbc_driver
      @confirmed_path = nil
      if @params[:jdbc_driver_jar] =~ /^http.*/i
        @target_path = '/tmp/jdbc.jar'
        @confirmed_path = File.exist?(@target_path) ? @target_path : download_driver_http
      elsif @params[:jdbc_driver_jar] =~ /^file.*/i
        @target_path = @params[:jdbc_driver_jar].gsub(/^file\:\/\//i, '')
        @confirmed_path = @target_path if File.exist?(@target_path)
      elsif @params[:jdbc_driver_jar] =~ /^s3.*/i
        @target_path = '/tmp/jdbc.jar'
        @confirmed_path = File.exist?(@target_path) ? @target_path : download_driver_s3
      else raise 'no suitable driver provided'
      end

      # rubocop says to turn this into a guard statement
      # but this needs the driver to be present before running
      if @params[:jdbc_driver_jar_md5]
        raise 'driver jar md5 mismatch' unless md5_check(
          @confirmed_path,
          @params[:jdbc_driver_jar_md5]
        )
      end
    end

    # downloads driver from an http source assuming no credentials
    # need to be provided
    def download_driver_http
      File.write(
        @target_path,
        open(@params[:jdbc_driver_jar]).read
      )
    end

    # downloads jar file from s3 source
    # uses standard AWS environment variables
    # or instance profile for credentials
    def download_driver_s3
      bucket_name = @params[:jdbc_driver_jar].match(
        /^s3\:\/\/([a-zA-Z0-9]|\.|\-)+/i
      )[0].gsub(/s3\:\/\//i, '')

      object_key = @params[:jdbc_driver_jar].gsub(
        /^s3\:\/\/([a-zA-Z0-9]|\.|\-)+\//i,
        ''
      )

      aws_creds =
      if ENV['AWS_ACCESS_KEY_ID']
        Aws::Credentials.new(
          ENV['AWS_ACCESS_KEY_ID'],
          ENV['AWS_SECRET_ACCESS_KEY']
        )
      else
        Aws::InstanceProfileCredentials.new
      end

      s3 = Aws::S3.new(
        region: ENV['AWS_REGION'],
        credentials: aws_creds
      )

      s3.get_object(
        response_target: @target_path,
        bucket: bucket_name,
        key: object_key
      )
    end

    # confirms that file md5 matches value provided
    # @param [String] file_path path to file
    # @param [String] file_md5 known md5 of file
    # @return [Boolean]
    def md5_check(file_path, file_md5)
      m = Digest::MD5.file(file_path)
      return true if m.hexdigest == file_md5
      false
    end

    # requires the jar file and jdbc driver class
    # into the current jruby context.  after this
    # runs all jdbc connections will use this driver class.
    def require_jdbc_driver
      require @confirmed_path
      java_import @params[:jdbc_driver_class]
    end
  end
end
