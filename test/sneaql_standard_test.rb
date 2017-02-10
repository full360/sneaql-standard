gem 'minitest'
require 'minitest/autorun'

require 'thread'


# provides empty test dbs
require_relative 'helpers/create_sqlite_db.rb'

# using a global variable because this is only a test
$base_path = File.expand_path("#{File.dirname(__FILE__)}/../")

require_relative "#{$base_path}/lib/sneaql_standard.rb"

class TestSneaqlStandard < Minitest::Test

  def set_required_env_vars()
    ENV['SNEAQL_JDBC_URL'] = 'jdbc:sqlite:localdb'
    ENV['SNEAQL_DB_USER'] = 'dbadmin'
    ENV['SNEAQL_DB_PASS'] = 'password'
    ENV['SNEAQL_JDBC_DRIVER_JAR'] = "file://#{$base_path}/test/fixtures/sqlite-jdbc-3.8.11.2.jar"
    ENV['SNEAQL_JDBC_DRIVER_CLASS'] = 'org.sqlite.JDBC'
  end

  def test_set_params_required()
    set_required_env_vars()

    s = Sneaql::SneaqlStandard.new()
    s.set_params()

    assert_equal(
      'jdbc:sqlite:localdb',
      s.params[:jdbc_url]
    )

    assert_equal(
      'dbadmin',
      s.params[:db_user]
    )

    assert_equal(
      'password',
      s.params[:db_pass]
    )

    assert_equal(
      "file://#{$base_path}/test/fixtures/sqlite-jdbc-3.8.11.2.jar",
      s.params[:jdbc_driver_jar]
    )

    assert_equal(
      'org.sqlite.JDBC',
      s.params[:jdbc_driver_class]
    )

    # this is a derived value
    assert_equal(
      'sqlite',
      s.params[:database]
    )

    # confirm defaults for optional env vars
    assert_equal(
      nil,
      s.params[:jdbc_driver_jar_md5]
    )

    assert_equal(
      'transform_steps_table',
      s.params[:step_metadata_manager_type]
    )

    assert_equal(
      '/tmp/sneaql/repos',
      s.params[:repo_base_dir]
    )

    assert_equal(
      1,
      s.params[:concurrency]
    )

    # another test to trigger errors if var is not provided
    ENV.delete('SNEAQL_DB_USER')
    err = nil
    begin
      s = Sneaql::SneaqlStandard.new()
      s.set_params()
    rescue => e
      err = e
    end

    assert_equal(
      "required environment variable SNEAQL_DB_USER not provided",
      e.message
    )

    # invalid required env_vars
    ENV['SNEAQL_JDBC_URL'] = 'https:notjdbc'
    err = nil
    begin
      s = Sneaql::SneaqlStandard.new()
      s.set_params()
    rescue => e
      err = e
    end

    assert_equal(
      "required environment variable SNEAQL_JDBC_URL looks invalid",
      e.message
    )

    set_required_env_vars()
    ENV['SNEAQL_JDBC_DRIVER_JAR'] = 'juggalo:nation'
    err = nil
    begin
      s = Sneaql::SneaqlStandard.new()
      s.set_params()
    rescue => e
      err = e
    end

    assert_equal(
      "required environment variable SNEAQL_JDBC_DRIVER_JAR looks invalid",
      e.message
    )
  end

  def test_set_params_optional()
    set_required_env_vars()

    # first check defaults are set correctly
    s = Sneaql::SneaqlStandard.new()
    s.set_params()

    assert_equal(
      nil,
      s.params[:jdbc_driver_jar_md5]
    )

    assert_equal(
      'transform_steps_table',
      s.params[:step_metadata_manager_type]
    )

    assert_equal(
      '/tmp/sneaql/repos',
      s.params[:repo_base_dir]
    )

    assert_equal(
      1,
      s.params[:concurrency]
    )

    assert_equal(
      'sneaql.transforms',
      s.params[:transform_table_name]
    )

    ENV['SNEAQL_JDBC_DRIVER_JAR_MD5'] = 'c56e036631557d93c9a28acd3a49e32b'
    ENV['SNEAQL_METADATA_MANAGER_TYPE'] = 'json_file'
    ENV['SNEAQL_REPO_BASE_DIR'] = '/tmp'
    ENV['SNEAQL_TRANSFORM_CONCURRENCY'] = '3'
    ENV['SNEAQL_TRANSFORM_TABLE_NAME'] = 'sneaql.transforms_test'

    s = Sneaql::SneaqlStandard.new()
    s.set_params()

    assert_equal(
      'c56e036631557d93c9a28acd3a49e32b',
      s.params[:jdbc_driver_jar_md5]
    )

    assert_equal(
      'json_file',
      s.params[:step_metadata_manager_type]
    )

    assert_equal(
      '/tmp',
      s.params[:repo_base_dir]
    )

    assert_equal(
      3,
      s.params[:concurrency]
    )

    assert_equal(
      'sneaql.transforms_test',
      s.params[:transform_table_name]
    )

  ensure
    # clean up
    ENV.delete('SNEAQL_JDBC_DRIVER_JAR_MD5')
    ENV.delete('SNEAQL_METADATA_MANAGER_TYPE')
    ENV.delete('SNEAQL_REPO_BASE_DIR')
    ENV.delete('SNEAQL_TRANSFORM_CONCURRENCY')
    ENV.delete('SNEAQL_TRANSFORM_TABLE_NAME')
  end

  def test_build_transform_queue()
    # build a test database
    sqlite_with_sneaql_objects('localdb')
    sqlite_populate_sneaql_objects('localdb')

    # set env vars
    set_required_env_vars()
    ENV['SNEAQL_TRANSFORM_TABLE_NAME'] = 'transforms'

    # create standard object
    s = Sneaql::SneaqlStandard.new()
    s.set_params()

    s.build_transform_queue()

    assert_equal(
      2,
      s.q.length
    )

    s.q.length.times do
      t = s.q.pop(true)

      assert_equal(
        Hash,
        t.class
      )

      assert_equal(
        true,
        ['test_transform_1', 'test_transform_2'].include?(t[:transform_name])
      )

      # confirm env supplied params
      [
        :jdbc_url,
        :db_user,
        :db_pass,
        :database,
        :transform_table_name
      ].each do |sym|
        assert_equal(
          s.params[sym],
          t[sym]
        )
      end

    end

  ensure
    ENV['SNEAQL_TRANSFORM_TABLE_NAME'] = 'sneaql.transforms'
    File.delete('localdb') if File.exists?('localdb')
  end

  def test_run_transforms()
    # build a test database
    sqlite_with_sneaql_objects('localdb')
    sqlite_populate_sneaql_objects('localdb')

    # set env vars
    set_required_env_vars()
    ENV['SNEAQL_TRANSFORM_TABLE_NAME'] = 'transforms'

    # create standard object
    s = Sneaql::SneaqlStandard.new()
    s.set_params()

    s.build_transform_queue()
    puts 'executed'
    tmp = []
    s.q.length.times do |o|
      p = s.q.pop(true)
      puts p
      tmp << p
    end

    tmp.each do |t|
      t[:repo_type] = 'local'
      t[:repo_base_dir] = "#{$base_path}/#{t[:repo_url].gsub('http://', '')}"
      t[:step_metadata_file_path] = "#{t[:repo_base_dir]}/sneaql.json"
      s.q.push t
    end

    s.run_transforms()

    connection = sqlite_connection('localdb')
    r = JDBCHelpers::QueryResultsToArray.new(
      connection,
      'select a from test order by a;'
    ).results

    assert_equal(
      3,
      r.length
    )

    r.each_with_index do |this_record, i|
      assert_equal(
        i + 1,
        this_record['a']
      )
    end

  ensure
    ENV['SNEAQL_TRANSFORM_TABLE_NAME'] = 'sneaql.transforms'
    File.delete('localdb') if File.exists?('localdb')
  end
end
  