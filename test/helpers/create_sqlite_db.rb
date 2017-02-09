require 'jdbc_helpers'
require 'sneaql'
require_relative '../fixtures/sqlite-jdbc-3.8.11.2.jar'
java_import 'org.sqlite.JDBC'

def sqlite_connection(path)
  JDBCHelpers::ConnectionFactory.new(
    "jdbc:sqlite:#{path}",
    '',
    ''
  ).connection
end

def sqlite_with_sneaql_objects(path)
  File.delete(path) if File.exists?(path)
  connection = sqlite_connection(path)

  db_manager = Sneaql::Core.find_class(
    :database,
    'sqlite'
  ).new

  creator = Sneaql::Standard::DBObjectCreator.new(
    connection,
    db_manager
  )

  creator.create_transforms_table(%{transforms})

  connection.close
end

def sqlite_populate_sneaql_objects(path)
  connection = sqlite_connection(path)

  db_manager = Sneaql::Core.find_class(
    :database,
    'sqlite'
  ).new

  creator = Sneaql::Standard::DBObjectCreator.new(
    connection,
    db_manager
  )

  JDBCHelpers::Execute.new(
    connection,
    creator.create_transform_statement(
      'transforms',
      {
        transform_name: 'test_transform_1',
        sql_repository: 'http://test/fixtures/test_transform_repo_1',
        sql_repository_branch: '',
        is_active: true,
        notify_on_success: 'false',
        notify_on_non_precondition_failure: 'false',
        notify_on_precondition_failure: 'false',
      }
    )
  )

  JDBCHelpers::Execute.new(
    connection,
    creator.create_transform_statement(
      'transforms',
      {
        transform_name: 'test_transform_2',
        sql_repository: 'http://test/fixtures/test_transform_repo_2',
        sql_repository_branch: '',
        is_active: true,
        notify_on_success: 'false',
        notify_on_non_precondition_failure: 'false',
        notify_on_precondition_failure: 'false',
      }
    )
  )

  connection.close
end

