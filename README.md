# Abilities

## Run:

Install mysql2 gem: 
`gem install mysql2`

Run:
`ruby main.rb`

## API

### INSERT
#### add(actor, subject):
Map that the actor has an ability over the subject. For instance:

- add('arthurnn', 'Team platform-data'): meaning 'arthurnn' is part of 'Team platform-data'
- add('Team platform-data', 'Repo x'): meaning 'Team platform-data' has a 'Repo x'

#### add_group(group, parent_id = nil)
Add a group which can have a parent group(parent_id).
Group is a node that will be added in a tree.
For instance:

- add_group('Team platform-data', 'Team platform'.id)

### SELECT
#### all_from(from, to_type)
Return a list of IDs quering all the nodes, with the type 'to_type', that 'from' has access to.
For instance:

- all_from('arthurnn', 'Repository): will return all repositories 'arthurnn' can access.

#### all_subgroups(group)
Returns all subgroups of a group (the entire sub-tree).


## Implementation details:

To map abilities(actor, subject) and multiple groups, we have two different tables:

- 'abilities': which saves the edges(connections) of two nodes that relate to each-other. And Actor can act in a Subject.
- 'rels': saves a florest of trees.

### How are we implementing the tree in MySQL?

Lets look at this example:
```
+------------+------------+----------+-------------------+
| id         | parent_id  | group_id | path_string       |
+------------+------------+----------+-------------------+
| 1007580937 |       NULL |        3 | 3C0E7709          |
| 3362383975 | 1007580937 |        5 | 3C0E7709/C869E867 |
| 3986040090 | 1007580937 |        4 | 3C0E7709/ED96251A |
+------------+------------+----------+-------------------+
```

In here, we have a tree with 3 nodes. A root node(1007580937), with two leaves(3362383975 and 3986040090).
Every node has a reference to a `group_id`, which could be a subject or actor back in the abilities table.
```
mysql> select * from teams;
+----+---------------+
| id | name          |
+----+---------------+
|  3 | platform      |
|  4 | platform-data |
|  5 | HA            |
+----+---------------+
```

Also, the most important part of this table is the `path_string` column. That column saves a HEX(id) path, separed by `/` of the path that leads to that node. (every node in a tree, can only have one path. Thats a tree property).
With that path, we can get any node, and walk up or down on that path. Getting the list of parent or children.
That allow us to query the tree without needing a recursive/CTE select.
Also, that avoids multiple level JOINS, as we have the entire path in any node.

Every time we add a node, we have the parent, so we can just append our id.
In the case of removal. We can `delete like path%` same as when we want to search a sub-tree.

#### What is the maximum deepth of this tree?
85 is the maximum number of levels this tree can get with this current implementation.
The calculation is the following:
765bytes / ((4bytes / 4bits) + 1byte) = 85

- 765bytes is the maximum allowed key size in a innodb table, so, if we want to have an index on it, thats the maximum bytes we can store.
- 4bytes is the size of an UNASSIGED INT int mysql.
- 4bits is the size that a hexadecimal char can hold ('F' = 1111 = 4 bits)
- 1byte the separator byte.

We don't save the `path_string` as of a path of IDS, even if thats what they are. Because that would take too much space. Instead we always do a `HEX(id)` before saving the path, so that allows to get to that 85 deepth.

#### Limitations
The calculation above assumes that we are using UNASSIGNED INT, and not BIGINT. If we want to use a BIGINT that means our maximum deepth would be 45.
If we want to increase the number of deepth, with a BIGINT, one thing we could do is instead of using the HEX function, we could implement our function that would take the id and transform it to a base 128 char, using ASCII table, and store that. Not sure how possible that would be though.

#### Why those IDs are so random?
The only reason the IDs on that table are random, is because I wanted to push it to the limits and needed to work with big size INTs. In real life, that should be a normal AUTO_INCREMENT column.


### Performance
Create/Insert and Delete are O(1), as we would just insert the group, without needing to cascade(denormalize) any other information.
Read is O(N), N been the deepth of the path we are fetching. Without the need to CTE or multiple JOINS. As we have the entire tree path in every node. We can, split the path, and directly fetch all nodes that the query needs to return, without any extra query.
