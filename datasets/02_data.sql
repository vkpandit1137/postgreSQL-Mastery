-- ============================================================================
-- 02_data.sql  —  Seed data for the practice schema
--
-- RUN AFTER 01_schema.sql, while connected to shopdb:
--     \i 02_data.sql
--
-- Shape of the data:
--    10 categories (a tree)      6 suppliers        25 products
--    24 customers                12 employees (a hierarchy)
--    60 orders                  105 order items    56 payments   36 reviews
--
-- Deliberate features you will use later in the program:
--    * NULLs in city, phone, birth_date, loyalty_tier, supplier_id, employee_id
--    * customers with no orders          (13, 18, 22, 23)
--    * products never ordered            (6, 16, 25)
--    * discontinued products             (6, 25)
--    * products with zero stock          (3, 6, 16, 25)
--    * orders with no payment            (cancelled 4/14/35, pending 58/59/60)
--    * refunds                           (orders 8 and 23)
--    * an employee with no manager       (employee 1)
--    * a self-referencing category tree  (parent_category_id)
--    * date range: 2024-01-08 .. 2025-07-07
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- categories
-- ----------------------------------------------------------------------------
INSERT INTO categories (category_id, category_name, parent_category_id, description) VALUES
 (1,  'Electronics',   NULL, 'All powered devices'),
 (2,  'Computers',     1,    'Desktops, laptops and computing gear'),
 (3,  'Laptops',       2,    'Portable computers'),
 (4,  'Phones',        1,    'Mobile telephones'),
 (5,  'Home & Living', NULL, 'Everything for the home'),
 (6,  'Kitchen',       5,    'Kitchen appliances and tools'),
 (7,  'Furniture',     5,    'Tables, chairs and storage'),
 (8,  'Books',         NULL, 'Printed and bound'),
 (9,  'Programming',   8,    'Software engineering titles'),
 (10, 'Accessories',   2,    'Peripherals and add-ons');

-- ----------------------------------------------------------------------------
-- suppliers
-- ----------------------------------------------------------------------------
INSERT INTO suppliers (supplier_id, supplier_name, country, contact_email, rating, active_since) VALUES
 (1, 'TechSource Global',   'Germany', 'orders@techsource.example',    4.5, '2019-03-01'),
 (2, 'Pacific Components',  'Taiwan',  'sales@pacificcomp.example',    4.2, '2020-07-15'),
 (3, 'Nordic Home Goods',   'Sweden',  NULL,                           4.8, '2018-01-20'),
 (4, 'Delhi Print House',   'India',   'hello@delhiprint.example',     3.9, '2021-11-02'),
 (5, 'Atlas Furniture Co',  'Poland',  'b2b@atlasfurniture.example',   4.0, '2017-06-30'),
 (6, 'Quantum Peripherals', 'China',   'export@quantumper.example',    3.5, '2022-02-11');

-- ----------------------------------------------------------------------------
-- products
-- ----------------------------------------------------------------------------
INSERT INTO products (product_id, product_name, category_id, supplier_id, price, cost, stock_quantity, weight_kg, is_discontinued, added_on) VALUES
 (1,  'Laptop Pro 14',                          3,  1,    1899.00, 1400.00,  12,  1.600, false, '2023-01-15'),
 (2,  'Laptop Air 13',                          3,  1,    1099.00,  800.00,  30,  1.200, false, '2023-02-10'),
 (3,  'Budget Laptop 15',                       3,  2,     549.00,  420.00,   0,  2.100, false, '2023-03-05'),
 (4,  'Smartphone X',                           4,  2,     999.00,  700.00,  45,  0.190, false, '2023-01-20'),
 (5,  'Smartphone Mini',                        4,  2,     699.00,  500.00,  20,  0.150, false, '2023-04-01'),
 (6,  'Old Phone 2020',                         4,  2,     299.00,  250.00,   0,  0.210, true,  '2020-05-01'),
 (7,  'Wireless Mouse',                         10, 6,      29.99,   12.00, 200,  0.090, false, '2023-01-05'),
 (8,  'Mechanical Keyboard',                    10, 6,      89.99,   45.00,  75,  0.950, false, '2023-01-05'),
 (9,  'USB-C Hub',                              10, 6,      49.99,   20.00, 150,  0.070, false, '2023-06-11'),
 (10, 'Laptop Stand',                           10, 6,      39.99,   15.00,  60,  0.800, false, '2023-06-11'),
 (11, 'Blender 500W',                           6,  3,      79.99,   40.00,  25,  2.400, false, '2023-02-14'),
 (12, 'Coffee Maker',                           6,  3,     129.99,   70.00,  18,  3.100, false, '2023-02-14'),
 (13, 'Chef Knife',                             6,  3,      59.99,   25.00,  40,  0.230, false, '2023-07-01'),
 (14, 'Office Chair',                           7,  5,     249.00,  150.00,  10, 12.500, false, '2023-03-22'),
 (15, 'Standing Desk',                          7,  5,     499.00,  320.00,   5, 28.000, false, '2023-03-22'),
 (16, 'Bookshelf',                              7,  5,     149.00,   80.00,   0, 19.400, false, '2023-08-09'),
 (17, 'Clean Code',                             9,  4,      39.50,   20.00, 100,  0.700, false, '2022-11-01'),
 (18, 'The Pragmatic Programmer',               9,  4,      45.00,   22.00,  80,  0.650, false, '2022-11-01'),
 (19, 'SQL Performance Explained',              9,  4,      34.95,   18.00,  35,  0.400, false, '2023-05-17'),
 (20, 'Designing Data-Intensive Applications',  9,  4,      55.00,   30.00,  60,  0.900, false, '2023-05-17'),
 (21, 'Noise Cancelling Headphones',            1,  1,     199.00,  120.00,  55,  0.280, false, '2023-09-01'),
 (22, 'Bluetooth Speaker',                      1,  6,      89.00,   45.00,  70,  0.550, false, '2023-09-01'),
 (23, 'Tablet 10',                              1,  2,     429.00,  300.00,  22,  0.470, false, '2023-10-05'),
 (24, 'Smart Watch',                            1,  2,     249.00,  160.00,  33,  0.045, false, '2023-10-05'),
 (25, 'Webcam HD',                              10, NULL,    69.00,   30.00,   0,  0.120, true,  '2021-06-15');

-- ----------------------------------------------------------------------------
-- customers
-- ----------------------------------------------------------------------------
INSERT INTO customers (customer_id, first_name, last_name, email, phone, city, country, signup_date, birth_date, loyalty_tier, is_active) VALUES
 (1,  'Anna',    'Muller',    'anna.mueller@example.com',      '+49-30-1234567',   'Berlin',    'Germany',     '2023-04-12', '1988-03-22', 'gold',     true),
 (2,  'Rajesh',  'Kumar',     'rajesh.kumar@example.com',      '+91-11-4455667',   'Delhi',     'India',       '2023-06-01', '1992-11-05', 'silver',   true),
 (3,  'Emily',   'Carter',    'emily.carter@example.com',      NULL,               'Austin',    'USA',         '2023-01-19', '1985-07-30', 'platinum', true),
 (4,  'Liu',     'Yang',      'liu.yang@example.com',          '+86-21-5566778',   'Shanghai',  'China',       '2024-02-14', NULL,         'bronze',   true),
 (5,  'Sofia',   'Rossi',     'sofia.rossi@example.com',       '+39-06-778899',    'Rome',      'Italy',       '2023-09-23', '1990-01-15', 'silver',   true),
 (6,  'James',   'Wilson',    'james.wilson@example.com',      '+44-20-33445566',  'London',    'UK',          '2022-11-30', '1979-05-09', 'gold',     true),
 (7,  'Marie',   'Dubois',    'marie.dubois@example.com',      NULL,               NULL,        'France',      '2024-05-02', '1995-08-19', 'bronze',   true),
 (8,  'Carlos',  'Silva',     'carlos.silva@example.com',      '+55-11-99887766',  'Sao Paulo', 'Brazil',      '2023-03-08', '1983-12-01', NULL,       false),
 (9,  'Yuki',    'Tanaka',    'yuki.tanaka@example.com',       '+81-3-12345678',   'Tokyo',     'Japan',       '2024-01-05', '1998-04-27', 'bronze',   true),
 (10, 'Olivia',  'Brown',     'olivia.brown@example.com',      '+1-416-5551234',   'Toronto',   'Canada',      '2022-08-17', '1991-09-14', 'gold',     true),
 (11, 'Ahmed',   'Hassan',    'ahmed.hassan@example.com',      '+20-2-24681357',   'Cairo',     'Egypt',       '2024-03-21', '1987-02-11', NULL,       true),
 (12, 'Ingrid',  'Nilsson',   'ingrid.nilsson@example.com',    '+46-8-1122334',    'Stockholm', 'Sweden',      '2023-07-14', '1993-06-06', 'silver',   true),
 (13, 'Daniel',  'Kim',       'daniel.kim@example.com',        NULL,               'Seoul',     'South Korea', '2024-06-30', NULL,         'bronze',   true),
 (14, 'Laura',   'Sanchez',   'laura.sanchez@example.com',     '+34-91-5556677',   'Madrid',    'Spain',       '2023-02-27', '1986-10-23', 'gold',     true),
 (15, 'Peter',   'Novak',     'peter.novak@example.com',       '+420-2-99887755',  'Prague',    'Czechia',     '2022-12-09', '1981-03-17', 'silver',   false),
 (16, 'Grace',   'Mwangi',    'grace.mwangi@example.com',      '+254-20-334455',   'Nairobi',   'Kenya',       '2024-04-18', '1996-12-25', 'bronze',   true),
 (17, 'Tom',     'Becker',    'tom.becker@example.com',        '+49-89-4433221',   'Munich',    'Germany',     '2023-10-11', '1990-07-04', 'silver',   true),
 (18, 'Nina',    'Petrova',   'nina.petrova@example.com',      NULL,               NULL,        'Russia',      '2024-07-22', '1994-05-30', NULL,       true),
 (19, 'Michael', 'O''Connor', 'michael.oconnor@example.com',   '+353-1-6677889',   'Dublin',    'Ireland',     '2023-05-16', '1977-11-12', 'platinum', true),
 (20, 'Fatima',  'Al-Sayed',  'fatima.alsayed@example.com',    '+971-4-3344556',   'Dubai',     'UAE',         '2024-08-09', '1989-09-02', 'gold',     true),
 (21, 'Lucas',   'Meyer',     'lucas.meyer@example.com',       '+49-40-7788990',   'Hamburg',   'Germany',     '2025-01-13', '2000-01-20', 'bronze',   true),
 (22, 'Hannah',  'Schmidt',   'hannah.schmidt@example.com',    NULL,               'Berlin',    'Germany',     '2025-02-28', '1999-03-08', NULL,       true),
 (23, 'Arjun',   'Mehta',     'arjun.mehta@example.com',       '+91-22-33445566',  'Mumbai',    'India',       '2025-03-17', '1997-06-21', 'bronze',   true),
 (24, 'Chloe',   'Martin',    'chloe.martin@example.com',      '+33-1-44556677',   'Paris',     'France',      '2025-04-05', '1992-12-14', 'silver',   true);

-- ----------------------------------------------------------------------------
-- employees  (employee 1 has no manager; everyone else reports upward)
-- ----------------------------------------------------------------------------
INSERT INTO employees (employee_id, first_name, last_name, email, manager_id, department, job_title, hire_date, salary, commission_pct) VALUES
 (1,  'Sofia',  'Lindqvist', 'sofia.lindqvist@shop.example', NULL, 'Management', 'Chief Executive Officer', '2016-02-01', 185000.00, NULL),
 (2,  'Marcus', 'Webb',      'marcus.webb@shop.example',     1,    'Sales',      'Sales Director',          '2017-05-15',  98000.00, 0.020),
 (3,  'Aiko',   'Tanaka',    'aiko.tanaka@shop.example',     1,    'Support',    'Support Lead',            '2018-09-03',  76000.00, NULL),
 (4,  'Priya',  'Nair',      'priya.nair@shop.example',      1,    'Warehouse',  'Warehouse Manager',       '2018-01-22',  71000.00, NULL),
 (5,  'Tom',    'Becker',    'tom.becker@shop.example',      2,    'Sales',      'Senior Sales Rep',        '2019-03-11',  62000.00, 0.045),
 (6,  'Lucia',  'Moretti',   'lucia.moretti@shop.example',   2,    'Sales',      'Sales Rep',               '2020-06-08',  54000.00, 0.040),
 (7,  'Omar',   'Haddad',    'omar.haddad@shop.example',     2,    'Sales',      'Sales Rep',               '2021-10-19',  51000.00, 0.040),
 (8,  'Grace',  'Okafor',    'grace.okafor@shop.example',    3,    'Support',    'Support Agent',           '2021-04-05',  44000.00, NULL),
 (9,  'Ivan',   'Petrov',    'ivan.petrov@shop.example',     3,    'Support',    'Support Agent',           '2022-08-29',  42000.00, NULL),
 (10, 'Chen',   'Wei',       'chen.wei@shop.example',        4,    'Warehouse',  'Warehouse Associate',     '2022-01-17',  38000.00, NULL),
 (11, 'Fatima', 'Zahra',     'fatima.zahra@shop.example',    4,    'Warehouse',  'Warehouse Associate',     '2023-05-02',  36500.00, NULL),
 (12, 'Liam',   'O''Brien',  'liam.obrien@shop.example',     2,    'Sales',      'Junior Sales Rep',        '2023-11-13',  41000.00, 0.030);

-- ----------------------------------------------------------------------------
-- orders
-- ----------------------------------------------------------------------------
INSERT INTO orders (order_id, customer_id, employee_id, order_date, status, shipping_city, shipping_country, shipping_cost) VALUES
 (1,  6,  5,    '2024-01-08', 'delivered', 'London',    'UK',      4.99),
 (2,  3,  6,    '2024-01-12', 'delivered', 'Austin',    'USA',     0.00),
 (3,  1,  5,    '2024-01-19', 'delivered', 'Berlin',    'Germany', 4.99),
 (4,  10, 7,    '2024-01-25', 'cancelled', 'Toronto',   'Canada',  9.99),
 (5,  2,  NULL, '2024-02-02', 'delivered', 'Delhi',     'India',   2.99),
 (6,  5,  6,    '2024-02-11', 'delivered', 'Rome',      'Italy',   5.49),
 (7,  4,  12,   '2024-02-14', 'delivered', 'Shanghai',  'China',   7.99),
 (8,  14, 5,    '2024-02-20', 'returned',  'Madrid',    'Spain',   5.49),
 (9,  6,  5,    '2024-03-01', 'delivered', 'London',    'UK',      4.99),
 (10, 9,  7,    '2024-03-05', 'delivered', 'Tokyo',     'Japan',   8.99),
 (11, 12, 6,    '2024-03-12', 'delivered', 'Stockholm', 'Sweden',  6.50),
 (12, 3,  6,    '2024-03-18', 'delivered', 'Austin',    'USA',     0.00),
 (13, 19, 12,   '2024-03-27', 'delivered', 'Dublin',    'Ireland', 5.99),
 (14, 11, NULL, '2024-04-03', 'cancelled', 'Cairo',     'Egypt',  11.99),
 (15, 1,  5,    '2024-04-09', 'delivered', 'Berlin',    'Germany', 4.99),
 (16, 8,  7,    '2024-04-15', 'delivered', 'Sao Paulo', 'Brazil', 12.50),
 (17, 16, 6,    '2024-04-22', 'delivered', 'Nairobi',   'Kenya',  13.00),
 (18, 10, 7,    '2024-04-28', 'delivered', 'Toronto',   'Canada',  9.99),
 (19, 6,  5,    '2024-05-06', 'delivered', 'London',    'UK',      0.00),
 (20, 5,  6,    '2024-05-13', 'shipped',   'Rome',      'Italy',   5.49),
 (21, 3,  12,   '2024-05-19', 'delivered', 'Austin',    'USA',     0.00),
 (22, 7,  NULL, '2024-05-24', 'delivered', 'Lyon',      'France',  6.99),
 (23, 15, 5,    '2024-06-02', 'returned',  'Prague',    'Czechia', 7.25),
 (24, 2,  NULL, '2024-06-10', 'delivered', 'Delhi',     'India',   2.99),
 (25, 20, 6,    '2024-06-16', 'delivered', 'Dubai',     'UAE',    10.00),
 (26, 19, 12,   '2024-06-23', 'delivered', 'Dublin',    'Ireland', 5.99),
 (27, 1,  5,    '2024-07-01', 'delivered', 'Berlin',    'Germany', 4.99),
 (28, 12, 6,    '2024-07-08', 'delivered', 'Stockholm', 'Sweden',  6.50),
 (29, 9,  7,    '2024-07-14', 'delivered', 'Tokyo',     'Japan',   8.99),
 (30, 17, 5,    '2024-07-21', 'delivered', 'Munich',    'Germany', 4.99),
 (31, 3,  6,    '2024-07-29', 'delivered', 'Austin',    'USA',     0.00),
 (32, 10, 7,    '2024-08-05', 'delivered', 'Toronto',   'Canada',  9.99),
 (33, 14, 12,   '2024-08-12', 'delivered', 'Madrid',    'Spain',   5.49),
 (34, 6,  5,    '2024-08-19', 'delivered', 'London',    'UK',      4.99),
 (35, 4,  NULL, '2024-08-27', 'cancelled', 'Shanghai',  'China',   7.99),
 (36, 11, 6,    '2024-09-03', 'delivered', 'Cairo',     'Egypt',  11.99),
 (37, 5,  6,    '2024-09-11', 'delivered', 'Rome',      'Italy',   5.49),
 (38, 19, 12,   '2024-09-18', 'delivered', 'Dublin',    'Ireland', 0.00),
 (39, 16, 7,    '2024-09-25', 'delivered', 'Nairobi',   'Kenya',  13.00),
 (40, 1,  5,    '2024-10-02', 'delivered', 'Berlin',    'Germany', 4.99),
 (41, 3,  6,    '2024-10-10', 'delivered', 'Austin',    'USA',     0.00),
 (42, 20, 12,   '2024-10-17', 'delivered', 'Dubai',     'UAE',    10.00),
 (43, 2,  NULL, '2024-10-24', 'delivered', 'Delhi',     'India',   2.99),
 (44, 12, 6,    '2024-11-01', 'delivered', 'Stockholm', 'Sweden',  6.50),
 (45, 6,  5,    '2024-11-08', 'delivered', 'London',    'UK',      4.99),
 (46, 9,  7,    '2024-11-15', 'delivered', 'Tokyo',     'Japan',   8.99),
 (47, 10, 7,    '2024-11-22', 'delivered', 'Toronto',   'Canada',  0.00),
 (48, 19, 12,   '2024-11-29', 'delivered', 'Dublin',    'Ireland', 5.99),
 (49, 3,  6,    '2024-12-05', 'delivered', 'Austin',    'USA',     0.00),
 (50, 1,  5,    '2024-12-12', 'delivered', 'Berlin',    'Germany', 4.99),
 (51, 14, 12,   '2024-12-19', 'shipped',   'Madrid',    'Spain',   5.49),
 (52, 17, 5,    '2024-12-27', 'delivered', 'Munich',    'Germany', 4.99),
 (53, 21, 6,    '2025-01-15', 'delivered', 'Hamburg',   'Germany', 4.99),
 (54, 5,  6,    '2025-02-03', 'delivered', 'Rome',      'Italy',   5.49),
 (55, 24, 12,   '2025-04-11', 'paid',      'Paris',     'France',  6.99),
 (56, 6,  5,    '2025-04-28', 'shipped',   'London',    'UK',      4.99),
 (57, 20, 7,    '2025-05-14', 'paid',      'Dubai',     'UAE',    10.00),
 (58, 3,  6,    '2025-06-02', 'pending',   'Austin',    'USA',     0.00),
 (59, 1,  5,    '2025-06-19', 'pending',   'Berlin',    'Germany', 4.99),
 (60, 16, 7,    '2025-07-07', 'pending',   'Nairobi',   'Kenya',  13.00);

-- ----------------------------------------------------------------------------
-- order_items
-- ----------------------------------------------------------------------------
INSERT INTO order_items (order_id, product_id, quantity, unit_price, discount_pct) VALUES
 (1,7,2,29.99,0.000),   (1,8,1,89.99,0.000),
 (2,1,1,1899.00,0.050), (2,9,1,49.99,0.000),
 (3,17,1,39.50,0.000),  (3,18,1,45.00,0.000),  (3,19,1,34.95,0.000),
 (4,14,1,249.00,0.000),
 (5,4,1,999.00,0.000),  (5,7,1,29.99,0.000),
 (6,11,1,79.99,0.000),  (6,12,1,129.99,0.100),
 (7,2,1,1099.00,0.000), (7,10,1,39.99,0.000),
 (8,21,1,199.00,0.000),
 (9,22,2,89.00,0.000),  (9,7,1,29.99,0.000),
 (10,23,1,429.00,0.000),(10,24,1,249.00,0.000),
 (11,15,1,499.00,0.000),(11,14,2,249.00,0.050),
 (12,20,1,55.00,0.000), (12,19,1,34.95,0.000),
 (13,1,1,1899.00,0.000),(13,8,1,89.99,0.000),  (13,7,1,29.99,0.000),
 (14,5,1,699.00,0.000),
 (15,12,1,129.99,0.000),(15,13,2,59.99,0.000),
 (16,3,1,549.00,0.000), (16,9,2,49.99,0.000),
 (17,17,2,39.50,0.000), (17,20,1,55.00,0.000),
 (18,4,1,999.00,0.100), (18,21,1,199.00,0.000),
 (19,7,3,29.99,0.000),  (19,10,2,39.99,0.000),
 (20,24,1,249.00,0.000),(20,22,1,89.00,0.000),
 (21,2,1,1099.00,0.050),
 (22,11,1,79.99,0.000),
 (23,15,1,499.00,0.000),
 (24,19,1,34.95,0.000), (24,18,1,45.00,0.000),
 (25,1,1,1899.00,0.000),(25,23,1,429.00,0.000),
 (26,8,2,89.99,0.000),  (26,9,1,49.99,0.000),
 (27,13,1,59.99,0.000), (27,12,1,129.99,0.000),
 (28,14,1,249.00,0.000),(28,10,1,39.99,0.000),
 (29,5,1,699.00,0.000), (29,24,1,249.00,0.000),
 (30,7,1,29.99,0.000),  (30,8,1,89.99,0.000),  (30,9,1,49.99,0.000), (30,10,1,39.99,0.000),
 (31,20,2,55.00,0.050),
 (32,3,2,549.00,0.000),
 (33,21,1,199.00,0.000),(33,22,1,89.00,0.000),
 (34,1,1,1899.00,0.100),
 (35,2,1,1099.00,0.000),
 (36,11,2,79.99,0.000), (36,13,1,59.99,0.000),
 (37,23,1,429.00,0.000),
 (38,17,1,39.50,0.000), (38,18,1,45.00,0.000), (38,19,1,34.95,0.000), (38,20,1,55.00,0.000),
 (39,4,1,999.00,0.000),
 (40,24,2,249.00,0.000),
 (41,1,1,1899.00,0.000),(41,15,1,499.00,0.000),
 (42,5,2,699.00,0.050),
 (43,7,2,29.99,0.000),
 (44,12,1,129.99,0.000),(44,11,1,79.99,0.000),
 (45,21,2,199.00,0.100),
 (46,23,1,429.00,0.000),(46,9,1,49.99,0.000),
 (47,14,1,249.00,0.000),(47,15,1,499.00,0.000),
 (48,2,1,1099.00,0.000),(48,8,1,89.99,0.000),
 (49,19,1,34.95,0.000), (49,17,1,39.50,0.000),
 (50,22,1,89.00,0.000), (50,24,1,249.00,0.000),
 (51,3,1,549.00,0.000),
 (52,10,2,39.99,0.000), (52,7,1,29.99,0.000),
 (53,8,1,89.99,0.000),  (53,9,1,49.99,0.000),
 (54,12,1,129.99,0.000),
 (55,20,1,55.00,0.000), (55,18,1,45.00,0.000),
 (56,1,1,1899.00,0.000),
 (57,4,1,999.00,0.000), (57,21,1,199.00,0.000),
 (58,13,1,59.99,0.000),
 (59,24,1,249.00,0.000),
 (60,11,1,79.99,0.000), (60,7,1,29.99,0.000);

-- ----------------------------------------------------------------------------
-- payments
-- Amounts equal the order's line total (qty x unit_price x (1 - discount))
-- plus shipping_cost, except where noted. Cancelled and pending orders have
-- no payment row. Orders 8 and 23 were paid and then refunded.
-- ----------------------------------------------------------------------------
INSERT INTO payments (order_id, paid_at, amount, method, status) VALUES
 (1,  '2024-01-08 14:22:00+00',  154.96, 'card',             'captured'),
 (2,  '2024-01-12 09:05:00+00', 1854.04, 'card',             'captured'),
 (3,  '2024-01-19 18:40:00+00',  124.44, 'paypal',           'captured'),
 (5,  '2024-02-02 07:15:00+00', 1031.98, 'bank_transfer',    'captured'),
 (6,  '2024-02-11 12:33:00+00',  202.47, 'card',             'captured'),
 (7,  '2024-02-14 03:58:00+00', 1146.98, 'card',             'captured'),
 (8,  '2024-02-20 16:10:00+00',  204.49, 'card',             'captured'),
 (8,  '2024-03-04 11:02:00+00',  204.49, 'card',             'refunded'),
 (9,  '2024-03-01 19:27:00+00',  212.98, 'paypal',           'captured'),
 (10, '2024-03-05 01:44:00+00',  686.99, 'card',             'captured'),
 (11, '2024-03-12 10:09:00+00',  978.60, 'bank_transfer',    'captured'),
 (12, '2024-03-18 15:51:00+00',   89.95, 'gift_card',        'captured'),
 (13, '2024-03-27 08:30:00+00', 2024.97, 'card',             'captured'),
 (15, '2024-04-09 17:05:00+00',  254.96, 'card',             'captured'),
 (16, '2024-04-15 20:12:00+00',  661.48, 'cash_on_delivery', 'captured'),
 (17, '2024-04-22 06:48:00+00',  147.00, 'card',             'captured'),
 (18, '2024-04-28 13:37:00+00', 1108.09, 'paypal',           'captured'),
 (19, '2024-05-06 09:19:00+00',  169.95, 'card',             'captured'),
 (20, '2024-05-13 14:02:00+00',  343.49, 'card',             'captured'),
 (21, '2024-05-19 11:26:00+00', 1044.05, 'card',             'captured'),
 (22, '2024-05-24 16:55:00+00',   86.98, 'paypal',           'captured'),
 (23, '2024-06-02 10:41:00+00',  506.25, 'card',             'captured'),
 (23, '2024-06-14 09:00:00+00',  506.25, 'card',             'refunded'),
 (24, '2024-06-10 05:33:00+00',   82.94, 'bank_transfer',    'captured'),
 (25, '2024-06-16 12:08:00+00', 2338.00, 'card',             'captured'),
 (26, '2024-06-23 18:14:00+00',  235.96, 'card',             'captured'),
 (27, '2024-07-01 08:52:00+00',  194.97, 'paypal',           'captured'),
 (28, '2024-07-08 15:30:00+00',  295.49, 'card',             'captured'),
 (29, '2024-07-14 02:21:00+00',  956.99, 'card',             'captured'),
 (30, '2024-07-21 19:46:00+00',  214.95, 'card',             'captured'),
 (31, '2024-07-29 13:03:00+00',  104.50, 'gift_card',        'captured'),
 (32, '2024-08-05 16:37:00+00', 1107.99, 'card',             'captured'),
 (33, '2024-08-12 09:58:00+00',  293.49, 'paypal',           'captured'),
 (34, '2024-08-19 11:11:00+00', 1714.09, 'card',             'captured'),
 (36, '2024-09-03 07:24:00+00',  231.96, 'cash_on_delivery', 'captured'),
 (37, '2024-09-11 14:49:00+00',  434.49, 'card',             'captured'),
 (38, '2024-09-18 10:05:00+00',  174.45, 'card',             'captured'),
 (39, '2024-09-25 08:17:00+00', 1012.00, 'bank_transfer',    'captured'),
 (40, '2024-10-02 17:42:00+00',  502.99, 'card',             'captured'),
 (41, '2024-10-10 12:26:00+00', 2398.00, 'card',             'captured'),
 (42, '2024-10-17 06:09:00+00', 1338.10, 'card',             'captured'),
 (43, '2024-10-24 04:55:00+00',   62.97, 'paypal',           'captured'),
 (44, '2024-11-01 15:18:00+00',  216.48, 'card',             'captured'),
 (45, '2024-11-08 18:33:00+00',  363.19, 'card',             'captured'),
 (46, '2024-11-15 01:07:00+00',  487.98, 'card',             'captured'),
 (47, '2024-11-22 14:44:00+00',  748.00, 'paypal',           'captured'),
 (48, '2024-11-29 09:52:00+00', 1194.98, 'card',             'captured'),
 (49, '2024-12-05 16:20:00+00',   74.45, 'gift_card',        'captured'),
 (50, '2024-12-12 10:38:00+00',  342.99, 'card',             'captured'),
 (51, '2024-12-19 13:15:00+00',  554.49, 'card',             'captured'),
 (52, '2024-12-27 11:47:00+00',  114.96, 'card',             'captured'),
 (53, '2025-01-15 15:22:00+00',  144.97, 'card',             'captured'),
 (54, '2025-02-03 09:41:00+00',  135.48, 'paypal',           'captured'),
 (55, '2025-04-11 12:03:00+00',  106.99, 'card',             'captured'),
 (56, '2025-04-28 17:29:00+00', 1903.99, 'card',             'captured'),
 (57, '2025-05-14 08:11:00+00', 1208.00, 'bank_transfer',    'captured');

-- ----------------------------------------------------------------------------
-- reviews
-- ----------------------------------------------------------------------------
INSERT INTO reviews (product_id, customer_id, rating, title, body, created_at, helpful_votes) VALUES
 (1,  3,  5, 'Worth every cent',        'Fast, silent, great screen.',                 '2024-01-25 10:00:00+00', 42),
 (1,  19, 4, 'Very good, very pricey',  'No complaints except the price tag.',         '2024-04-02 14:30:00+00', 18),
 (1,  20, 5, 'Best laptop I have owned','Battery lasts a full working day.',           '2024-07-01 09:15:00+00', 27),
 (1,  6,  3, 'Runs hot',                'Fans spin up under any real load.',           '2024-09-12 16:45:00+00',  9),
 (2,  4,  4, 'Light and capable',       'Perfect for travel.',                         '2024-03-01 08:20:00+00', 12),
 (2,  3,  5, 'Excellent value',         'Does everything I need.',                     '2024-06-10 11:05:00+00', 15),
 (2,  19, 4, 'Solid machine',           'Keyboard could be better.',                   '2024-12-20 13:40:00+00',  6),
 (3,  8,  2, 'You get what you pay for','Slow after a few months.',                    '2024-06-05 17:55:00+00', 31),
 (3,  10, 3, 'Fine for the price',      'Screen is dim but usable.',                   '2024-09-01 10:22:00+00',  7),
 (4,  2,  5, 'Superb camera',           'Night shots are a huge upgrade.',             '2024-02-20 07:30:00+00', 55),
 (4,  10, 4, 'Great phone',             'Battery could be better.',                    '2024-05-18 19:12:00+00', 21),
 (4,  16, 5, 'Flawless',                'Nothing to fault.',                           '2024-10-11 06:40:00+00', 13),
 (5,  9,  4, 'Small and fast',          'Fits in any pocket.',                         '2024-08-02 12:18:00+00', 10),
 (5,  20, 3, 'Screen too small for me', 'Great hardware, wrong size.',                 '2024-11-05 15:33:00+00',  4),
 (7,  6,  5, 'Cheap and perfect',       'Bought three of them.',                       '2024-01-15 09:44:00+00', 34),
 (7,  2,  4, 'Good mouse',              'Battery life is excellent.',                  '2024-02-25 14:07:00+00',  8),
 (7,  17, 2, 'Died after 3 months',     'Scroll wheel stopped working.',               '2024-09-14 18:21:00+00', 47),
 (8,  6,  5, 'Fantastic typing feel',   'Loud, but I like it.',                        '2024-01-20 11:52:00+00', 29),
 (8,  19, 4, 'Great build',             'Heavy, which I consider a feature.',          '2024-07-05 08:09:00+00', 11),
 (9,  3,  4, 'Does the job',            'Gets warm under load.',                       '2024-02-01 16:26:00+00',  5),
 (9,  12, 5, 'One cable for everything','Exactly what I wanted.',                      '2024-07-12 10:48:00+00', 16),
 (11, 5,  4, 'Powerful little blender', 'Crushes ice without complaint.',              '2024-02-28 13:14:00+00', 14),
 (11, 11, 5, 'Excellent',               'Used daily for six months, still perfect.',   '2024-10-01 07:37:00+00', 19),
 (12, 5,  3, 'Average coffee',          'Convenient but not great coffee.',            '2024-03-02 06:55:00+00', 22),
 (12, 1,  4, 'Good machine',            'Easy to clean.',                              '2024-07-20 15:01:00+00',  9),
 (13, 1,  5, 'Razor sharp',             'Holds its edge remarkably well.',             '2024-05-01 12:42:00+00', 25),
 (14, 12, 4, 'Comfortable',             'Assembly took an hour.',                      '2024-04-01 09:28:00+00', 17),
 (14, 10, 2, 'Armrests broke',          'Plastic parts failed within weeks.',          '2024-12-02 17:16:00+00', 38),
 (15, 12, 5, 'Life changing',           'Wish I had bought it years ago.',             '2024-04-05 08:03:00+00', 44),
 (17, 1,  5, 'A classic',               'Every engineer should read it once.',         '2024-02-05 20:11:00+00', 61),
 (17, 16, 3, 'Dated in places',         'Good ideas, aging examples.',                 '2024-05-10 14:55:00+00', 28),
 (19, 1,  5, 'Short and brilliant',     'Explains indexes better than anything else.', '2024-02-08 19:34:00+00', 73),
 (19, 3,  5, 'Essential',               'Read it twice.',                              '2024-04-01 10:19:00+00', 52),
 (20, 3,  5, 'The best systems book',   'Dense but worth the effort.',                 '2024-04-03 11:47:00+00', 88),
 (20, 16, 4, 'Heavy going',             'Excellent, but not a beach read.',            '2024-05-12 16:02:00+00', 24),
 (21, 14, 4, 'Great noise cancelling',  'Cuts out plane engine noise entirely.',       '2024-03-10 13:29:00+00', 20);

COMMIT;

-- ----------------------------------------------------------------------------
-- Move each identity sequence past the highest id we inserted by hand, so that
-- future INSERTs that omit the id do not collide. (Explained on Day 54.)
-- ----------------------------------------------------------------------------
SELECT setval(pg_get_serial_sequence('categories','category_id'), (SELECT max(category_id) FROM categories));
SELECT setval(pg_get_serial_sequence('suppliers','supplier_id'),  (SELECT max(supplier_id)  FROM suppliers));
SELECT setval(pg_get_serial_sequence('products','product_id'),    (SELECT max(product_id)   FROM products));
SELECT setval(pg_get_serial_sequence('customers','customer_id'),  (SELECT max(customer_id)  FROM customers));
SELECT setval(pg_get_serial_sequence('employees','employee_id'),  (SELECT max(employee_id)  FROM employees));
SELECT setval(pg_get_serial_sequence('orders','order_id'),        (SELECT max(order_id)     FROM orders));

ANALYZE;

\echo '02_data.sql : seed data loaded.'
