/*Создайте таблицу logs типа Archive. Пусть при каждом создании записи в таблицах users, catalogs и products
 в таблицу logs помещается время и дата создания записи, название таблицы, идентификатор первичного ключа и 
 содержимое поля name.
 */
drop table  if exists logs;
create table logs (
	log_time datetime default CURRENT_TIMESTAMP,
	table_name varchar(255),
	id_logged_table int,
	name_logged_table varchar(255))
	ENGINE  = archive;
-- добавим триггеры:
drop trigger if exists log_insert_products;
drop trigger if exists log_insert_users;
drop trigger if exists log_insert_catalogs;
delimiter //
create trigger log_insert_products after insert on products -- а вот кстати как сделать это одним триггером? или вобще без триггеров надо было?
for each row
begin
	 insert logs (table_name, id_logged_table, name_logged_table) select  'products', new.id, new.name from products limit 1; 
	 -- что-то странное и это грязный костыль. если убрать limit1 то в логе будет столько  строк на каждую запись 
	 -- сколько строк в отслеживаемой таблице
	 -- угу, посмотрел разбор, понял косяк (таки селект зря, да), но пусть останется как сам делал
end//
create trigger log_insert_users after insert on users 
for each row
begin
	 insert logs (table_name, id_logged_table, name_logged_table) select 'users', new.id, new.name from users limit 1;
end//
create trigger log_insert_catalogs after insert on catalogs -- or users or catalogs
for each row
begin
	 insert logs (table_name, id_logged_table, name_logged_table) select 'catalogs', new.id, new.name from catalogs limit 1;
end//
delimiter ;

-- проверяем:

INSERT INTO catalogs VALUES
  (NULL, 'тесте15');
INSERT INTO users (name, birthday_at) VALUES
  ('Тестировщик12', '1999-9-9');
INSERT INTO products
  (name, description, price, catalog_id)
VALUES
  ('тестдата', 'тестовый набор для тестирования тестов', 7777.00, 7);
	
/*(по желанию) Создайте SQL-запрос, который помещает в таблицу users миллион записей.
*/
 -- 1 вариант
drop procedure if exists generate_user;
delimiter //
create PROCEDURE generate_user(counter int)
begin	
while counter > 0 do
set counter = counter - 1;
insert users (name, birthday_at) values (UUID(), FROM_UNIXTIME(1447430881 + counter, '%Y-%m-%d'));
end while;
end //
delimiter ;

call generate_user(1000000); -- 1,5 секунты на 1к строк, ну в принципе 200 тысяч строк вставилось минут за 5, но я забоялся и рестартанул сервер

-- второй вариант, отключим автокоммит:
truncate users; -- чистка

drop procedure if exists generate_user;
delimiter //
create PROCEDURE generate_user(counter int)
begin
SET autocommit=0;	
while counter > 0 do
set counter = counter - 1;
insert users (name, birthday_at) values (UUID(), FROM_UNIXTIME(1447430881 + counter, '%Y-%m-%d'));
end while;
COMMIT;
SET autocommit=1;
end //
delimiter ;


call generate_user(1000); -- 1к строк вставляется за  1,2 секунды. вероятно если не генерить uid будет быстрее
-- логика подсказывает что  что гдето 20 минут ждать. пока оно молотит я погуглю.
-- select count(*) from users;
truncate users;
call generate_user(1000000); -- фокус с коммитом работает но скорости это не прибавило... итого вышло 24 минуты
truncate users;

-- 3 вариант
drop procedure if exists generate_user1;
delimiter //
create PROCEDURE generate_user1(counter int)
begin	
	
drop temporary table if exists my_tmp;
create temporary table my_tmp (name char(36), birthday_at date);
while counter > 0 do
	insert my_tmp (name, birthday_at) values(
				UUID(), FROM_UNIXTIME(1447430881 , '%Y-%m-%d'));
				 set counter = counter - 1;
end while;
SET autocommit=0;
insert users (name, birthday_at) select * from my_tmp;
COMMIT;
SET autocommit=1;
end //
delimiter ;

call generate_user1(1000); -- 101 мс на 1000 строк
truncate users;
call generate_user1(1000000);  -- 1 минута 45 секунды  

-- ну и для чистоты эксперимента с константами:
drop procedure if exists generate_user2;
delimiter //
create PROCEDURE generate_user2(counter int)
begin	
	
drop temporary table if exists my_tmp;
create temporary table my_tmp (name char(36), birthday_at date);
while counter > 0 do
	insert my_tmp (name, birthday_at) values(
				'username', '2020-12-05');
				 set counter = counter - 1;
end while;
SET autocommit=0;
insert users (name, birthday_at) select * from my_tmp;
COMMIT;
SET autocommit=1;
end //
delimiter ;

call generate_user2(1000); -- 95мс
call generate_user2(1000000); -- 90 секунд.
truncate users;
-- а эксплейн у меня почему-то на вызов процедуры не работает(((

-- посмотрел разбор, разочарован... А у меня зато уникальные записи

