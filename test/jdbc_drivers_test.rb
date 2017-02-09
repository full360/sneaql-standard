gem 'minitest'
require 'minitest/autorun'

# using a global variable because this is only a test
$base_path = File.expand_path("#{File.dirname(__FILE__)}/../")

require_relative "#{$base_path}/lib/sneaql_standard_lib/jdbc_drivers.rb"

class TestJDBCDriverHandler < Minitest::Test
  def test_download_driver_s3()
    # this is a standard http/s downloader so no need for
    # the test to pull a jdbc file
  end

  def test_confirm_jdbc_driver
    # first confirm it with a local file
    j = Sneaql::JDBCDriverHandler.new(
      {
        jdbc_driver_jar: "file://#{$base_path}/test/fixtures/sqlite-jdbc-3.8.11.2.jar"
      }
    )
    j.confirm_jdbc_driver
    assert_equal(
      "#{$base_path}/test/fixtures/sqlite-jdbc-3.8.11.2.jar",
      j.confirmed_path
    )

    # local file failure scenario
    j = Sneaql::JDBCDriverHandler.new(
      {
        jdbc_driver_jar: "file://#{$base_path}/test/fixtures/doesnotexist"
      }
    )
    j.confirm_jdbc_driver
    assert_equal(
      nil,
      j.confirmed_path
    )

    # now test local file with md5
    j = Sneaql::JDBCDriverHandler.new(
      {
        jdbc_driver_jar: "file://#{$base_path}/test/fixtures/sqlite-jdbc-3.8.11.2.jar",
        jdbc_driver_jar_md5: 'c56e036631557d93c9a28acd3a49e32b'
      }
    )
    j.confirm_jdbc_driver
    assert_equal(
      "#{$base_path}/test/fixtures/sqlite-jdbc-3.8.11.2.jar",
      j.confirmed_path
    )

    # local file with md5 failure
    j = Sneaql::JDBCDriverHandler.new(
      {
        jdbc_driver_jar: "file://#{$base_path}/test/fixtures/sqlite-jdbc-3.8.11.2.jar",
        jdbc_driver_jar_md5: 'josemadre'
      }
    )
    err = nil
    begin
      j.confirm_jdbc_driver
    rescue => e
      err = e
    end
    assert_equal(
      'driver jar md5 mismatch',
      err.message
    )

  end

#  def test_download_driver_http()
#    target = '/tmp/sneaql-standard-http-download-test.zip'
#    File.delete()
#    j = Sneaql::JDBCDriverHandler.new(
#      {
#        jdbc_driver_jar: 'https://github.com/full360/jdbc-helpers/archive/master.zip'
#      }
#    )
#
#    j.target_path = target
#    j.download_driver_http()
#
#    assert_equal(
#      true,
#      File.exists?(target)
#    )
#  end

  def test_md5_check()
    j = Sneaql::JDBCDriverHandler.new({})

    assert_equal(
      true,
      j.md5_check(
        "#{$base_path}/test/fixtures/sqlite-jdbc-3.8.11.2.jar",
        'c56e036631557d93c9a28acd3a49e32b'
      )
    )

    assert_equal(
      false,
      j.md5_check(
        "#{$base_path}/test/fixtures/sqlite-jdbc-3.8.11.2.jar",
        'abcdefghijklmnop'
      )
    )
  end

  def test_require_jdbc_driver
    j = Sneaql::JDBCDriverHandler.new(
      {
        jdbc_driver_class: 'org.sqlite.JDBC'
      }
    )

    j.confirmed_path = "#{$base_path}/test/fixtures/sqlite-jdbc-3.8.11.2.jar"
    j.require_jdbc_driver()

    connection = java.sql.DriverManager.get_connection(
      'jdbc:sqlite:',
      '',
      ''
    )

    assert_equal(
      Java::OrgSqlite::SQLiteConnection,
      connection.class
    )

    connection.close
  end
end