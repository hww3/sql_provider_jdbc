inherit .utils;

//! an object representing a JDBC Prepared statement
//!
//! this class emulates named (:param) parameters and accepts binding arguments
//! keyed using either the named parameter, if it exists or the position of the 
//! argument using its index number. Positional binding works regardless of whether
//! the query was constructed using named parameters.
//!
//! CompiledStatement objects are bound to the JDBC connection they were created from,
//! and are closed when an exception occurs. Otherwise, a compiled statement may be
//! reused. Bindings are saved between executions, so once bound may be used without 
//! rebinding, or may be rebound as necessary. See @[bind], @[clear_parameters], 
//! @[Sql.Sql.compile_query].
object compiled_statement;

protected void create(.jdbc connection, string statement)
{
   string st = convert_placeholders(statement);
   compiled_statement = connection->master_connection()->prepareStatement(st);
   //werror("in: %O\nout:%O\n", statement, st);
}

//! returns the low-level JDBC Statement object.
public object get_statement() {
  return compiled_statement;
}

protected void bind_parameter(array(int) args, string|int key, mixed val) {
  foreach(args;; int pos) {
    if(intp(val)) 
      compiled_statement->setInt(pos, val);    
    else if(stringp(val))  
      compiled_statement->setString(pos, val);    
    else if(floatp(val))  
      compiled_statement->setFloat(pos, val);    
    else if(isBlob(val))  
      compiled_statement->setBlob(pos, valToBlob(val));    
    else if(isNull(val))	  
	  compiled_statement->setNull(pos, 0); // need to set the parameter type correctly.
	else if(objectp(val)) {
	  if(Program.implements(object_program(val), Calendar.YMD))
	    compiled_statement->setDate(Java.pkg["java/sql/Date"](val->ux*1000));
  	  else if(Program.implements(object_program(val), Calendar.YMD_Time))
  	    compiled_statement->setDate(Java.pkg["java/sql/Time"](val->ux*1000));		
	}
	else throw(Error.Generic("Unable to set value for parameter "  + key + ": Unknown or unsupported type.\n"));
  }
}	


//! binds the parameters supplied to the statement.
//! parameters bound are retained unless explicitly cleared.
//! subsequent calls may use existing bound parameters, overwrite some or all, or may 
//! completely clear the parameters using @[clear_parameters].
//!
//! @note
//!  not all java bindings are currently supported. More advanced needs may be met by getting
//!  the JDBC Statement object and operating directly on its methods. See @[get_statement].
public object bind(mixed...extraargs) {
  if (sizeof(extraargs)) {
    if(mappingp(extraargs[0])) {
      mapping(string|int:mixed) bindings = extraargs[0];		
	  foreach(bindings; mixed key; mixed val) {
	    string nkey = key;
	    if(intp(key))
		  bind_parameter(({key}), key, val);
		array args;
	    if((args = arg_to_position[nkey])) {
		  bind_parameter(args, key, val);
		} else {
		  throw(Error.Generic("No binding parameter in query for " + key  + ".\n"));
		}
	  }
	}
	else
	  throw(Error.Generic("sprintf style bindings not supported.\n"));
    }
  }

//!
void clear_parameters() {
  compiled_statement->clearParameters();
}

protected int isNull(mixed val) {
  return objectp(val) && val == Sql.NULL;
}

protected int isBlob(mixed val) {
  return (multisetp(val) && sizeof(val) == 1);
}

protected object valToBlob(multiset|Stdio.Buffer|String.Buffer val) {
   throw(Error.Generic("Setting BLOB parameter is not currently supported"));
}

protected void destroy() {
  if(compiled_statement && !compiled_statement->isClosed())
    compiled_statement->close();
}