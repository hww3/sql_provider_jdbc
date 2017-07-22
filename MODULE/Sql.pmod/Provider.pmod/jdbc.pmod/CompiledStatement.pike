inherit .utils;

object compiled_statement;
mapping arg_to_position = ([]);

protected void create(object connection, string statement)
{
   string st = convert_placeholders(statement);
   //compiled_statement = connection->prepareStatement(st);
   werror("in: %O\nout:%O\n", statement, st);
}

