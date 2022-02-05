# vfk (view sql-foreign-key)

This package holds source for building a command line tool which will generate diagrams on SQL database focusing on foreign keys. (ER diagram)

Why, there are plenty dozens of similair tools. Well...

1. The generated diagrams are strict heirarchy layed out, and sorted on name, as a grid or matrix and are close to stable even when the the database is changed. At the topmost row are the entity tables and below are the relationship tables. I think that is important for understanding and documentation.
3. Besides importing from runnung database like ``mysql``, ``postgres`` and ``sqlite`` you can import definitions from files (generated views from other database or test files) 

An example from the very early Chris Dates books with appropriate user and password

```shell
shell : vfk -q mysql://<user>:<password>@localhost -d chrisdate -o christdate.svg
```

Then drop the file into some web broswer like Safari, Firefox, Chrome or just open it from a shell.

```shell
shell : open christdate.svg -a safari
```

The drawing will show primary keys inside blue a box, and each foreign key set in a yellow box, and all the references enumareted :

#### Top down hierarchy

![Alt need ./chrisdate.svg](./chrisdate.svg "./chrisdate.svg")

#### Left right hierarchy

There is an option where the drawings is transposed so that entity tables are at left and relationship tables ordered to the right

```shell
shell : vfk -t -q mysql://<user>:<password>@localhost -d chrisdate -o christdate.svg
```


![Alt need ./chrisdatetransposed.svg](./chrisdatetransposed.svg "./chrisdatetransposed.svg")


## Installation

You have to install the ``crystal`` toolset. On Mac you can use

```shell
shell : brew install crystal
```

After downloding this site you can direct build the appliction and run it

```shell
shell : shards build 
shell : ./bin/vfk -h
```

## Usage

```shell
shell : ./bin/vfk -h
    -v, --version                    Show version
    -h, --help                       Show help
    -q, --sqlengine SQLENGINE        String to database open (DB.open())
                                     Ex: mysql://user:password@localhost/information_schema
    -d, --database DATABASENAME      Name of database to display. 
                                     Ex: sales
    -o, --outsvgfile FILENAME        Name of svg file displaying result
                                     Ex: /svgs/sales.svg
    -x, --exclude LISTOFTABLE        Exclude this list of tables
                                     Ex: "options,users,log,cakes"
    -c, --connected_only             Exclude all isolated tables
    -a, --attribute_hide             Exclude all attributes. Focus on structure
    -z, --zoom scale                 Scale with factor
                                     Ex: -z 0.8 will scale down to 80%
    -i, --import METAFILES           Import from offline db
                                     Ex: -i "f1,f2,f3"
    -t, --transpose                  Let entity tables line in first column. Default is in first row
    -s, --share_inconnections        Let inrefs share the same connection at end. Default now
```

Some explainations

* -q could be ``mysql``, ``postgres`` or ``sqlite``. Ensure the have sufficient privileges
* -d is only required on ``mysql``
* -z might be useful because browser and scaling to fit paper size does not always work properly in all web browsers
* -i this could also be used for importing testfiles or exported view from other database

### Import format -i

This seems to be an odd switch. But there several conditions when it migth be useful

* You can't access the mysql, postgres or sqlite database due to protection
* You have an engine like MS-SQL, Orcale, DB2 etc where there is no driver in crystal yet. You can generate the three views below by using the statements in the source ``dbclient``. They are most portable as the Information Schema is an ANSI standard. Then import the result in the -i switch
* Verify the tool
* You don't even have foreign but want to sketch on foreign keys
* You want to analyze and document the constraint.

The files is in CSV format without columns and has comma sign as separator.

#### Set 1 (tables and columns)

Holds tablename and columnname like (partial)

```
p,pno
p,pname
p,color
s,sno
s,sname
...
```

#### Set 2 (tables and primary keys)
Holds tablename and columnname like (partial)

```
j,jno
p,pno
s,sno
sp,sno
sp,pno
...
```

#### Set 2 (foreign key constraints)
Holds fromtablename, constraintname,fromcolumn,totable,tocolumn like (partial)

```
sp,sp_ibfk_1,pno,p,pno
sp,sp_ibfk_2,sno,s,sno
...
```

## Examples

### No attributes by -a

This is a way to reduce the overall size of the drawing. Just primary keys and foreign keys are drawn.

```shell
shell : ./bin/vfk -a -d northwind -q mysql://<user>:<passwordn@localhost -o northwind.svg
```
and you get

![Alt need ./northwind.svg](./northwind.svg "./northwind.svg")

### Share inconnections by -s

When there are lots of tables it could be usefule to combine in connections to avoid multiply lines

```shell
shell : ./bin/vfk -a -d northwind -q mysql://<user>:<passwordn@localhost -o northwind.svg
```
and you get

![Alt need ./northwindshared.svg](./northwindshared.svg "./northwindshared.svg")

### Scale using -z 
Use this when you must fit a drawing to a page print. Not all browser will scale properly without clipping some information

```shell
shell : ./bin/vfk -z 0.50 -d chinook -q mysql://<user>:<passwordn@localhost -o chinook.svg
```
and you get

![Alt need ./chinook.svg](./chinook.svg "./chinook.svg")

### Complex Foreign Kyes

When the foreign keys are complex the advantage of this drawing is obvious. This is an example from collecting basic information on trams and busses in order to generate interactive drawings in a metropolitan

![Alt need ./gbgtrams.svg](./gbgtrams.svg "./gbgtrams.svg")

and result in trams through the selected stop 'Valand' in Gothenborg, Sweden

![Alt need ./dynmetro.png](./dynmetro.png "./dynmetro.png")

### Transpose -t

If you prefer having entity tables the left and depending realitionship tables to the right use ``-t option``

![Alt need ./gbgtramstransposed.svg](./gbgtramstransposed.svg "./gbgtramstransposed.svg")

## For the record

1. This is my first attempt in evaluating ``Crystal``. No background from ``ruby`` besides some plug-ins to ``Sketchup`` several years ago
2. I must say I'm really amused. Language is easy to read and write with straightforward patterns and mechanisms. Contains a broad ready to be used functions. Productive in very short time with impressive speed and size for the self-contained load module. Definitely the first choice when doing real programs!!!
3. This fantastic ``github`` is a marvel in it's content. But the process for manage it is a
disaster in mine opinion. There are at least 490 tutorials, several desktops applications and plenty of web intefaces. A lot of tool, information, roles and procedures. The amount of guiding
can be interpreted as 'much is uncertain'. And also all remains from CVS and SVN in mine mind. That's the reason I will not maintain a shared update - pull request? But of course I will comment abd take actions on issuses. (At my age I have another speed and also shrinking collaboration capabilities. I might screw things up)
4. The ``crystal`` energy footprint seems to me small in runtime. It's fast as most says. This could be a sale point. Soon I hope!
