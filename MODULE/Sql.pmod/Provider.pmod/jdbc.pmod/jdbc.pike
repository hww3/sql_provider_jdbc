#if constant(Java.jvm)

object conn;
object lastWarning;

//!
int conn_timeout = 5; // wait 5 seconds for the server to reply.

//! 
int return_result_count = 0;

  protected void create(string jdbcUrl, string database, string user, string password, mapping|void options) {
    object properties = Java.pkg.java.util.Properties();
    if(user)
      properties->setProperty("user", user);
    if(password)
      properties->setProperty("password", password);
    if(options)
      foreach(options; string k; mixed v) 
        properties->setProperty(k, v);
		
	string dbstring; 
		
    if(database && jdbcUrl && sizeof(database) && sizeof(jdbcUrl))
	  throw(Error.Generic("jdbcUrl and database parameters cannot both be provided.\n"));
	else if(database && sizeof(database))
	  dbstring = database;
	else if(jdbcUrl && sizeof(jdbcUrl))
	  dbstring = jdbcUrl;
	else
	  throw(Error.Generic("Either jdbcUrl or database must be provided.\n"));  
    conn = Java.pkg["java/sql/DriverManager"]->getConnection(dbstring, properties);
  }

  string server_info() {
    object dmd = conn->getMetaData();
    string info = (string)dmd->getDatabaseProductName();
    info += "/" + (string)dmd->getDatabaseProductVersion();
    info += "@" + (string)dmd->getURL();
    return info;
  }

  int(0..1) is_open() { 
    return !conn->isClosed();
  }

  int(0..1) ping() {
    return conn->isValid(conn_timeout);
  }

  int|string error() {
    object w = getLastWarning();

    return (w && (string)w->getMessage()) || 0;
  }

  object getLastWarning() {
    if(!conn) return 0;
    object warning = conn->getWarnings();
    object w = warning;
    if(!warning) return 0;

    while(w = w->getWarning())
      warning = w;

    return warning;
  }

  int|string sqlstate() {
    object w = getLastWarning();
    return (w && (string)w->getSQLState()) || 0;
  }

  object master_connection() {
    return conn;
  }
//! @note
//!   this perfoms a call to setCatalog(), which for databases such as MySQL, sets the datbase. Its behavior 
//!   for other database drivers will vary.
void select_db(string db)
{
  conn->setCatalog(db);
}

void select_schema(string schema) 
{
  conn->setSchema(schema);
}

//! @note: for queries that return no results, such as insert, this the underlying driver will provide 
//!   the result count from the driver, which may be an integer other than zero. to receive this number
//!   rather than the customary zero (0), set the @[return_result_count] flag.
object|int streaming_query(string|.CompiledStatement query, mixed... extraargs) {
   object stmt;
   mixed err;
   int res;
   
   if(objectp(query)) {
      if(query->isClosed())
	    throw(Error.Generic("CompiledStatement is closed and must be recompiled.\n"));
      if(extraargs && sizeof(extraargs))
	    query->bind(@extraargs);
	  stmt = query->get_statement();	
      err = catch(res = stmt->execute());
   }
   else {
     stmt = conn->createStatement();
     err = catch(res = stmt->execute(query));
   }
   
   if(err) {
     stmt->close();
     lastWarning = err;
     throw(err);
   }

   if(!res) {
     int cnt = stmt->getUpdateCount();
     stmt->close();
     return (return_result_count?cnt:0);
   }
   return .jdbc_result(stmt->getResultSet());
 }

object|int big_query(string|object query, mixed...  extraargs) {
  return streaming_query(query, @extraargs);
}

object compile_query(string query) {
  return .CompiledStatement(this, query);
}

 mixed execute(string query) {
   object stmt = conn->createStatement();

   mixed r = stmt->execute(query);
  stmt->close();
  return r;
}

#else
  protected void create() {
    throw(Error.Generic("Java not present. Unable to create JDBC connection.\n"));
}
#endif
