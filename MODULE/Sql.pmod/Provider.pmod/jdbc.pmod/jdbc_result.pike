/*
  if(!res) {
     mixed result = stmt->getResultCount();
     stmt->close();
     return result;
   }
   resultSet = stmt->getResultSet();
   object md = resultset->getMetaData();
   int colCount = md->getColumnCount();
   if(colCount == 0) return 0;
   array cols = allocate(colCount);
   mixed cn = md->getColumnLabel;
   werror("cn: %O\n", cn);
   for(int x = 0; x < colCount; x++)
     cols[x] = (string)cn(x+1);

   ADT.List result = ADT.List();
   object getString = resultset->getString;
   while(resultset->next()) {
      mapping m = ([]);
      for(int i = 0; i < colCount; i++) {
        m[cols[i]] = (string)getString(i+1);
      }
      result->append(m);
   }
   stmt->close();
   return (array)result;
*/
#pike __REAL_VERSION__

//inherit .sql_object_result;

object resultSet;
object metaData;
array(mapping) fieldData;
int index = 0;

void create(object rs) {
   resultSet = rs;
}

//! @note
//!   this operation may be expensive, as it requires the result set to be cycled through
//!   in order to determine the number of rows. Also, the result set may not permit repositioning.
int num_rows() {

  if(resultSet->getType() ==  Java.pkg["java/sql/ResultSet"]->TYPE_FORWARD_ONLY)
    throw(Error.Generic("Unable to determine row count on a forward-only result set.\n"));
  resultSet->last();
  int row = resultSet->getRow();
  resultSet->absolute(index);
  return row;
}

int num_fields()
{
  if(!metaData) metaData = resultSet->getMetaData();
  return metaData->getColumnCount();
}

int eof() {
  return resultSet->isLast() || resultSet->isAfterLast();
}

array(mapping(string:mixed)) fetch_fields() {
  if(fieldData) return fieldData;
  if(!metaData) metaData = resultSet->getMetaData();
  int cc = metaData->getColumnCount();
  array fieldData2 = allocate(cc);

  for(int i = 0; i < cc; i++) {
    mapping fd = ([]);
    fd->name = (string)metaData->getColumnLabel(i+1);
    fd["length"] = metaData->getPrecision(i+1);
    fd["type"] = (string)metaData->getColumnTypeName(i+1);
    fd["decimals"] = metaData->getScale(i+1);
    fd["not_null"] = !metaData->isNullable(i+1);

    fieldData2[i] = fd;
  }

  fieldData = fieldData2;
  return fieldData;
}

//! @note 
//!   skip may be positive (forward) or negative (backward), depending on whether the result set allows
//!   backward motion.
void seek(int skip) {
    resultSet->relative(skip);
    index += skip;
}

int|array(string|int) fetch_row() {
  index++;
 return next_and_fetch();
}

protected array|int next_and_fetch() {
  if(!resultSet->next()) {
    return 0; // should we close the result set or not?
  }
  index++;
  array fields = fetch_fields();

  array res = allocate(sizeof(fields));

  string s;
  for(int i = 0; i < sizeof(fields); i++) {
    s = resultSet->getString(i+1);
    if(!s) res[i] = s;
    else res[i] = (string)s;
  }

  return res;
}

this_program next_result()
{
  object stmt = resultSet->getStatement();
  int more = stmt->getMoreResults();
  return more?this_program(stmt->getResultSet()):0;
}

void close() {
  resultSet->close();
}

protected void destroy() {
  if(resultSet && !resultSet->isClosed()) resultSet->close();
}
