-- start from scratch
DROP TABLE IF EXISTS loan;

DROP TABLE IF EXISTS copy;

DROP TABLE IF EXISTS book;

DROP TABLE IF EXISTS student;

DROP VIEW IF EXISTS cmp_students;

DROP PROCEDURE IF EXISTS new_loan;

DROP TRIGGER IF EXISTS loan_update;

-- create tables
CREATE TABLE book (
	isbn CHAR(17) NOT NULL,
	title VARCHAR(30) NOT NULL,
	author VARCHAR(30) NOT NULL,
	CONSTRAINT pri_book PRIMARY KEY (isbn),
	CONSTRAINT uni_title UNIQUE (title));

CREATE TABLE copy (
	`code` INT NOT NULL, 
	isbn CHAR(17) NOT NULL, 
	duration TINYINT NOT NULL,
	CONSTRAINT pri_copy PRIMARY KEY (`code`),
	CONSTRAINT for_copy FOREIGN KEY (isbn)
		REFERENCES book (isbn) 
			ON UPDATE CASCADE ON DELETE RESTRICT,
	CONSTRAINT chk_duration CHECK (duration IN (7, 14, 21)));

CREATE TABLE student (
	`no` INT NOT NULL,
	`name` VARCHAR(30) NOT NULL,
	school CHAR(3) NOT NULL,
	embargo BIT(1) NOT NULL DEFAULT b'0',
	CONSTRAINT pri_student PRIMARY KEY (`no`));

CREATE TABLE loan (
	`code` INT NOT NULL,
	`no` INT NOT NULL,
	taken DATE NOT NULL,
	due DATE NOT NULL,
	`return` DATE NULL,
	CONSTRAINT pri_loan PRIMARY KEY (`code`, `no`, taken),
	CONSTRAINT for_loan_copy FOREIGN KEY (`code`)
		REFERENCES copy (`code`)
		    ON UPDATE CASCADE ON DELETE RESTRICT,
	CONSTRAINT for_loan_student FOREIGN KEY (`no`)
		REFERENCES student (`no`)
			ON UPDATE CASCADE ON DELETE RESTRICT);

-- book data.
INSERT INTO book (isbn, title, author)
	VALUES ('111-2-33-444444-5', 'Pro JavaFX', 'Dave Smith');

INSERT INTO book (isbn, title, author)
	VALUES ('222-3-44-555555-6', 'Oracle Systems', 'Kate Roberts');

INSERT INTO book (isbn, title, author)
	VALUES ('333-4-55-666666-7', 'Expert jQuery', 'Mike Smith');
	
	
-- copy data.
INSERT INTO copy (`code`, isbn, duration)
	VALUES (1011, '111-2-33-444444-5', 21);

INSERT INTO copy (`code`, isbn, duration)
	VALUES (1012, '111-2-33-444444-5', 14);

INSERT INTO copy (`code`, isbn, duration)
	VALUES (1013, '111-2-33-444444-5', 7);
	
INSERT INTO copy (`code`, isbn, duration)
	VALUES (2011, '222-3-44-555555-6', 21);

INSERT INTO copy (`code`, isbn, duration)
	VALUES (3011, '333-4-55-666666-7', 7);

INSERT INTO copy (`code`, isbn, duration)
	VALUES (3012, '333-4-55-666666-7', 14);

-- student data.
INSERT INTO student (`no`, `name`, school, embargo)
	VALUES (2001, 'Mike', 'CMP', b'0');

INSERT INTO student (`no`, `name`, school, embargo)
	VALUES (2002, 'Andy', 'CMP', b'1');

INSERT INTO student (`no`, `name`, school, embargo)
	VALUES (2003, 'Sarah', 'ENG', b'0');

INSERT INTO student (`no`, `name`, school, embargo)
	VALUES (2004, 'Karen', 'ENG', b'1');

INSERT INTO student (`no`, `name`, school, embargo)
	VALUES (2005, 'Lucy', 'BUE', b'0');
	
-- loan data.
INSERT INTO loan (`code`, `no`, taken, due, `return`)
	VALUES (1011, 2002, '2017.01.10', '2017.01.31', '2017.01.31');
	
INSERT INTO loan (`code`, `no`, taken, due, `return`)
	VALUES (1011, 2002, '2017.02.05', '2017.02.26', '2017.02.23');
		
INSERT INTO loan (`code`, `no`, taken, due)
	VALUES (1011, 2003, '2017.05.10', '2017.05.31');
	
INSERT INTO loan (`code`, `no`, taken, due, `return`)
	VALUES (1013, 2003, '2016.03.02', '2016.03.16', '2016.03.10');
		
INSERT INTO loan (`code`, `no`, taken, due, `return`)
	VALUES (1013, 2002, '2016.08.02', '2016.08.16', '2016.08.16');
		
INSERT INTO loan (`code`, `no`, taken, due, `return`)
	VALUES (2011, 2004, '2015.02.01', '2015.02.22', '2015.02.20');
		
INSERT INTO loan (`code`, `no`, taken, due)
	VALUES (3011, 2002, '2017.07.03', '2017.07.10');
		
INSERT INTO loan (`code`, `no`, taken, due, `return`)
	VALUES (3011, 2005, '2016.10.10', '2016.10.17', '2016.10.20');

-- create view 
CREATE VIEW cmp_students 
	AS SELECT `no`,  `name`, school, embargo 
	FROM student 
	WHERE school = 'CMP' 
	WITH CHECK OPTION;
	
-- test view with invalid update (returns error)
UPDATE cmp_students SET school = 'ENG';


DELIMITER $$

CREATE PROCEDURE `new_loan`(IN book_isbn CHAR(17), IN student_`no` INT)
	
BEGIN
		
	-- search for the copy of the book
	-- test for loan record in loan table
	DECLARE copy_code, loan_test INT;
		
	-- test for successful loan.
	-- test for end of cursor
	DECLARE inserted, complete BOOLEAN;
      
	-- the duration date and current
	-- for new loan issue
	-- number of days for new loan.
	DECLARE due, cur DATE;
	DECLARE copy_dur TINYINT;
        
	-- test for student's ablility to loan books.
	DECLARE embargo_status BIT(1) DEFAULT b'1';
        
	-- cursor for copy ‘code’s based on isbn provided.
	DECLARE  copy_c CURSOR FOR
		SELECT `code`
		FROM copy 
		WHERE isbn = book_isbn;
		
	DECLARE CONTINUE HANDLER FOR NOT FOUND	
		SET complete = TRUE;
	

	-- open cursor.
	OPEN copy_c;
        
	-- get given student embargo status.
	SET embargo_status = (SELECT embargo 
					FROM student
					WHERE `no` = student_no);
                            
	SELECT embargo_status;
		
	



-- check if the student is valid or is not under embargo. 
	-- if not report appropriate message.
	IF (embargo_status IS NULL OR embargo_status = b'1') THEN
		SIGNAL SQLSTATE '45000'
			SET MESSAGE_TEXT = 'The student is not valid or is under embargo!';		
	END IF;	

	SET inserted = FALSE;
        
	SET copy_code = 0;
		
	-- loop through copies to get a when that is available. 
	copy_codes : LOOP
        
		-- get the item fro the set.	 
		FETCH NEXT FROM copy_c INTO copy_code;
            
		-- ‘no’ more ‘code’s in set.
		IF(complete)THEN
			LEAVE copy_codes;
		END IF;
            
		-- if a copy is available then
		-- loan_test will be null. If
       		 -- return is null means the book is out on loan
        		-- and a non null value will be 
       		 -- returned to loan_test. 
		SET loan_test = (SELECT `code` FROM loan
					WHERE (`code` = copy_code) 
					AND (`return` IS NULL));
		
        		-- If a copy is avaible loan_test will null.
       		 -- A null value implies that the copy had a one or many 
        		-- records in loan with a non null return or the copy was never
       		 -- out on loan. 
		IF(loan_test IS NULL) THEN
			
            			-- get the current date.
			SET cur = CURRENT_DATE();
			
           			 -- get duration for copy
			SET copy_dur = (SELECT duration
						FROM copy
						WHERE `code` = copy_code);
			
		
			-- calculate due date.
			SET due = DATE_ADD(cur, INTERVAL copy_dur DAY);
                
			-- issue the new loan.
			INSERT INTO loan (`code`, `no`, taken, due)
					VALUES (copy_code, student_no, cur, due);
			
           		 	-- set inserted to true.
			SET inserted = TRUE;
			
			-- quit loop to stop possible duplicate 
			-- loan insertions.
			LEAVE copy_codes;
		END IF;
		
	END LOOP;
	
    -- close cursor 
	CLOSE copy_c;	
	
   	 -- inform users of a failed loan.
	IF(inserted = FALSE) THEN
		SIGNAL SQLSTATE '45000'
			SET MESSAGE_TEXT = 'No available copies or book does not exist!';
	END IF;
 END$$
	
DELIMITER ;

-- create table for audit trail.
CREATE TABLE audit (
	`no` INT NOT NULL,
	taken DATE NOT NULL,
	due DATE NOT NULL,
	`return` DATE NULL
);

delimiter $$

-- trigger to execute on update.
CREATE TRIGGER loan_update AFTER
	UPDATE ON loan FOR EACH ROW
	BEGIN 
		IF(OLD.`return` IS NULL) AND (CURRENT_DATE() > OLD.due) THEN 
			INSERT INTO audit (`no`, taken, due, `return`) 
				VALUES (NEW.`no`, NEW.taken, NEW.due, NEW.`return`); 
		END IF;
	END$$
DELIMITER ;


-- number 1 
SELECT isbn, title, author
	FROM book;


-- number 2 	
SELECT `no`, `name`, school 
	FROM student 
	ORDER BY school DESC;

-- number 3	
SELECT isbn, title 
	FROM book 
	WHERE author LIKE ‘%Smith%’;
	
-- number 4
SELECT MAX(due) AS ‘lastest due date’
	FROM loan;

-- number 5
SELECT `no`
	FROM loan
	WHERE due = 
		(SELECT MAX(due) 
			FROM loan);

-- number 6
SELECT `no`, `name` 
	FROM student
	WHERE `no` = 
		( SELECT loan.`no`
			FROM loan
			WHERE loan.due =
				(SELECT MAX(due) 
					FROM loan));
					
-- number 7
SELECT `no`, `code`, due
	FROM loan 
	WHERE (YEAR(taken) = YEAR(CURRENT_DATE()))
		AND (`return` IS NULL);

-- number 8
SELECT student.`no`, student.`name`
	FROM student INNER JOIN loan
		ON student.`no` = loan.`no`
	WHERE loan.due = 
		(SELECT MAX(due) 
			FROM loan);

-- number 9
SELECT DISTINCT S.`no`, S.`name`,
		B.isbn, B.title
		FROM copy C INNER JOIN loan L
			ON L.`code` = C.`code`
		INNER JOIN student S
			ON L.`no` = S.`no`
		INNER JOIN book B
			ON C.isbn = B.isbn
		WHERE C.duration = 7;

-- number 10 
SELECT  B.title AS `Book Title`, COUNT(B.title) AS Frequency 
		FROM book AS B INNER JOIN copy AS C 
			ON B.isbn = C.isbn 
		INNER JOIN loan AS L 
			ON C.`code` = L.`code` 
		GROUP BY B.title 
			HAVING (COUNT(B.title)) > 1;
