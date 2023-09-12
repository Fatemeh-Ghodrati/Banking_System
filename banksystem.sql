CREATE TABLE IF NOT EXISTS Account(
	account_id SERIAL,
	username VARCHAR(40) UNIQUE,
	accountNumber VARCHAR(16) UNIQUE,
	pass VARCHAR(100),
	first_name VARCHAR(20),
	last_name VARCHAR(20),
	national_id VARCHAR(20),
	date_of_birth DATE,
	typ VARCHAR(20),
	interest_rate INT,
	PRIMARY KEY(username, accountNumber),
	CONSTRAINT account_checking CHECK (
	typ in ('employee', 'client')
	)
);

CREATE TABLE IF NOT EXISTS Login_Log(
	username VARCHAR(40),
	login_time TIMESTAMP,
	FOREIGN KEY (username) REFERENCES Account(username)
);

CREATE TABLE IF NOT EXISTS Transactions(
	typ VARCHAR(10),
	transaction_time TIMESTAMP,
	fromm VARCHAR(16),
	too VARCHAR(16),
	amount DECIMAL(13,3),
	FOREIGN KEY (fromm) REFERENCES Account(accountNumber),
	FOREIGN KEY (too) REFERENCES Account(accountNumber),
	CONSTRAINT transaction_checking CHECK 
	(typ in ('deposit', 'withdraw', 'transfer', 'interest'))
);

CREATE TABLE IF NOT EXISTS Latest_Balances(
	accountNumber VARCHAR(16),
	amount DECIMAL(13,3),
	FOREIGN KEY (accountNumber) REFERENCES Account(accountNumber)
);

CREATE TABLE IF NOT EXISTS Snapshot_Log(
	snapshot_id SERIAL,
	snapshot_timestamp TIMESTAMP,
	PRIMARY KEY (snapshot_id)
);

CREATE OR REPLACE FUNCTION create_account()
	RETURNS TRIGGER 
	LANGUAGE plpgsql
	AS $$
	BEGIN
		NEW.username = NEW.first_name || NEW.last_name;
		NEW.accountNumber = 585983110000 + NEW.account_id;
		IF NEW.typ = 'employee'
		THEN
			New.interest_rate = 0;
		END IF;
		RETURN NEW;
	END;
$$
;

CREATE OR REPLACE FUNCTION latest_balance_insert()
	RETURNS TRIGGER
	LANGUAGE PLPGSQL
	AS $$
	BEGIN 
		INSERT INTO Latest_Balances VALUES(NEW.accountNumber, 0);
		RETURN NEW;
	END;
$$
;

CREATE OR REPLACE TRIGGER create_account_trig
	BEFORE INSERT
	ON Account
	FOR EACH ROW
	EXECUTE FUNCTION create_account();
	
CREATE OR REPLACE TRIGGER latest_balance_insert_trig
	AFTER INSERT
	ON Account
	FOR EACH ROW
	EXECUTE FUNCTION latest_balance_insert();

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE OR REPLACE PROCEDURE register (
IN pass VARCHAR(100), IN first_name VARCHAR(20), IN last_name VARCHAR(20),
IN national_id VARCHAR(20), IN date_of_birth DATE, IN typ VARCHAR(20), IN interest_rate VARCHAR(20))
	LANGUAGE PLPGSQL
	AS $$
	DECLARE
		age INT = DATE_PART('year', AGE(date_of_birth));
		username1 VARCHAR(40);
	BEGIN
		IF age < 13
		THEN
			RAISE NOTICE 'Sorry! You are under 13';
			RETURN;
		END IF;
		username1 = first_name || last_name;
		IF username1 in (SELECT username from Account)
		THEN
			RAISE NOTICE 'You already have an account!';
			RETURN;
		END IF;
		INSERT INTO Account(username, accountNumber, pass, first_name, last_name,
							national_id, date_of_birth, typ, interest_rate) 
							VALUES('0', '0',crypt(pass, gen_salt('bf')),
				first_name, last_name, 
				national_id, date_of_birth, typ, CAST(interest_rate AS INTEGER));
		RAISE NOTICE 'Registerd Successfuly.Your username is %', username1;
		RAISE NOTICE 'Your Account Number is %', (SELECT accountNumber
												 FROM Account
												 WHERE username = username1);
	END;
$$
;
	
CREATE OR REPLACE PROCEDURE login (IN input_user VARCHAR(40), IN input_pass VARCHAR(100))
	LANGUAGE PLPGSQL
	AS $$
	DECLARE
		account_user VARCHAR(20);
	BEGIN 
		SELECT Account.username INTO account_user
		FROM Account
		WHERE Account.username = input_user and Account.pass = crypt(input_pass, Account.pass);
		IF account_user IS NULL
		THEN
			RAISE NOTICE 'login failed';
			RETURN;
		END IF;
		INSERT INTO Login_Log VALUES(account_user, CURRENT_TIMESTAMP);
		RAISE NOTICE 'login successfuly';
	END;
$$
;
	
CREATE OR REPLACE PROCEDURE deposite (IN amount DECIMAL(13,3))
	LANGUAGE PLPGSQL
	AS $$
	DECLARE
		account_user VARCHAR(40);
		account_number VARCHAR(20);
	BEGIN
		SELECT username INTO account_user
		FROM Login_Log
		ORDER BY login_time DESC
		LIMIT 1;
		
		SELECT accountNumber INTO account_number
		FROM Account
		WHERE Account.username = account_user;
		
		INSERT INTO Transactions(typ, transaction_time, fromm, amount) 
		VALUES ('deposit', CURRENT_TIMESTAMP, account_number, amount);
		RAISE NOTICE 'Deposited Successfyly!';
	END;
$$
;

CREATE OR REPLACE PROCEDURE withdraw (IN amount DECIMAL(13,3))
	LANGUAGE PLPGSQL
	AS $$
	DECLARE
		account_user VARCHAR(40);
		account_number VARCHAR(20);
		old_amount DECIMAL(13,3);
	BEGIN
		SELECT username INTO account_user
		FROM Login_Log
		ORDER BY login_time DESC
		LIMIT 1;
		
		SELECT accountNumber INTO account_number
		FROM Account
		WHERE Account.username = account_user;
		
		SELECT Latest_Balances.amount INTO old_amount
		FROM Latest_Balances
		WHERE Latest_Balances.accountNumber = account_number;
		
		IF old_amount < amount
		THEN
			RAISE NOTICE 'You Cant Withdraw';
			RETURN;
		ELSE
			INSERT INTO Transactions(typ, transaction_time, fromm, amount)
			VALUES ('withdraw', CURRENT_TIMESTAMP, account_number, amount);
			RAISE NOTICE 'Withdrew Successfuly!';
		END IF;
	END;
$$
;

CREATE OR REPLACE PROCEDURE transfer (IN account_number2 VARCHAR(16), IN amount DECIMAL(13,3))
	LANGUAGE PLPGSQL
	AS $$
	DECLARE
		username1 VARCHAR(40);
		username2 VARCHAR(40);
		account_number1 VARCHAR(16);
	BEGIN
		SELECT username INTO username1
		FROM Login_Log
		ORDER BY login_time DESC
		LIMIT 1;
		
		SELECT Account.accountNumber INTO account_number1
		FROM Account
		WHERE Account.username = username1;
		
		IF account_number1 = account_number2
		THEN
			RAISE NOTICE 'You Cant Transfer to Your Account';
			RETURN;
		END IF;
		
		SELECT username INTO username2
		FROM Account
		WHERE accountNumber = account_number2;
		
		IF amount < 0
		THEN
			RAISE NOTICE 'Amount Must be Positive!';
			RETURN;
		END IF;
		
		IF (SELECT Latest_Balances.amount FROM Latest_Balances WHERE accountNumber = account_number1) - amount < 0
		THEN
			RAISE NOTICE 'You Cant Transfer';
			RETURN;
		END IF;
		
		IF username2 IS NULL
		THEN 
			RAISE NOTICE 'Invalid account number';
			RETURN;
		ELSE
		INSERT INTO Transactions VALUES ('transfer', CURRENT_TIMESTAMP, account_number1,
										account_number2, amount);
		RAISE NOTICE 'Transferd successfuly!';
		END IF;
	END;
$$
;

CREATE OR REPLACE PROCEDURE interest_payment ()
	LANGUAGE PLPGSQL
	AS $$
	DECLARE
		account_user VARCHAR(40);
		account_number VARCHAR(16);
		rate INT;
		account_amount DECIMAL(13,3);
	BEGIN
		SELECT username INTO account_user
		FROM Login_Log
		ORDER BY login_time DESC
		LIMIT 1;
		
		SELECT accountNumber, interest_rate  INTO account_number, rate
		FROM Account
		WHERE Account.username = account_user;
		
		SELECT amount INTO account_amount
		FROM Latest_Balances
		WHERE Latest_Balances.accountNumber = account_number;
		
		account_amount = account_amount + (account_amount * rate);
	
		INSERT INTO Transactions(typ, transaction_time, fromm, amount)
		VALUES ('interest', CURRENT_TIMESTAMP, account_number, account_amount);
		RAISE NOTICE 'Interest Paid Successfuly!';
	END;
$$
;

CREATE OR REPLACE PROCEDURE update_balances ()
	LANGUAGE PLPGSQL
	AS $$
	DECLARE
		time1 TIMESTAMP;
		f RECORD;
		tableName TEXT;
		account_user VARCHAR(40);
		user_typ VARCHAR(20);
	BEGIN
		SELECT snapshot_timestamp INTO time1
		FROM Snapshot_Log
		ORDER BY snapshot_timestamp DESC
		LIMIT 1;
		
		SELECT username INTO account_user
		FROM Login_Log
		ORDER BY login_time DESC
		LIMIT 1;
		
		SELECT typ INTO user_typ
		FROM Account
		WHERE Account.username = account_user;
		
		IF user_typ = 'client'
		THEN
			RAISE NOTICE 'You Cant Update';
			RETURN;
		END IF;
		
		FOR f IN SELECT * FROM transactions WHERE time1 IS NULL OR transaction_time > time1
		LOOP
			IF f.typ = 'deposite'
			THEN
				UPDATE Latest_Balances
				SET amount = amount + f.amount
				WHERE Latest_Balances.accountNumber = f.fromm;
				RAISE NOTICE 'deposite update!';
			ELSIF f.typ = 'withdraw'
			THEN
				UPDATE Latest_Balances
				SET amount = amount - f.amount
				WHERE Latest_Balances.accountNumber = f.fromm;
			ELSIF f.typ = 'transfer'
			THEN 
				UPDATE Latest_Balances
				SET amount = Latest_Balances.amount + f.amount
				WHERE Latest_Balances.accountNumber = f.too;
				UPDATE Latest_Balances
				SET amount = Latest_Balances.amount - f.amount
				WHERE Latest_Balances.accountNumber = f.fromm;
			ELSE
				UPDATE Latest_Balances
				SET amount = f.amount
				WHERE Latest_Balances.accountNumber = f.fromm;
			END IF;
		END LOOP;
		INSERT INTO Snapshot_Log(snapshot_timestamp) VALUES(CURRENT_TIMESTAMP);
		tableName := 'snapshot_' || (SELECT MAX(snapshot_id) FROM Snapshot_Log);
		EXECUTE 'CREATE TABLE ' || tableName || ' AS SELECT * FROM Latest_Balances;';
		RAISE NOTICE 'Updated Successfuly!';
	END;
$$
;

CREATE OR REPLACE PROCEDURE check_balance()
	LANGUAGE PLPGSQL
	AS $$
	DECLARE
		account_user VARCHAR(40);
		account_number VARCHAR(16);
		latest_amount DECIMAL(13,3);
	BEGIN
		SELECT username INTO account_user
		FROM Login_Log
		ORDER BY login_time DESC
		LIMIT 1;
		
		SELECT accountNumber INTO account_number
		FROM Account
		WHERE username = account_user;
		
		SELECT amount INTO latest_amount
		FROM Latest_Balances
		WHERE accountNumber = account_number;
		RAISE NOTICE 'Latest Balance: %', latest_amount;
		
	END;
$$
;