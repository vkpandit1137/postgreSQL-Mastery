1. Run SELECT 5 / 2;. The answer is not 2.5. Write down what you think is happening. assumption : we are truncating/rounding off towards zero.
ans : SELECT 5 / 2; returns 2. Both operands are integers, so PostgreSQL does integer division and truncates toward zero. It does not round — 7 / 2 is 3, not 4. 

2.  the // comment attempt instead of --
3. the + newline marker, \n becomes the part of output value if we do 
postgres=# SELECT 'unclosed
postgres'# '
postgres-# ;
 ?column? 
----------
 unclosed+
 
(1 row)
