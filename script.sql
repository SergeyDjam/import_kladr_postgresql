
CREATE TABLE W_LOCALITY_TYPE(
	ID 			bigserial NOT NULL PRIMARY KEY,
	NAME			character varying(64) DEFAULT NULL UNIQUE,
	CREATE_DATE		TIMESTAMP with time zone NOT NULL DEFAULT NOW()
);

CREATE TABLE W_LOCALITY(
	ID 			bigserial NOT NULL PRIMARY KEY,
	PARENT_ID		bigint,
	NAME			character varying(64) DEFAULT NULL,
	LOCALITY_TYPE_ID 	bigint NOT NULL references W_LOCALITY_TYPE(ID),
	KLADR_ID		VARCHAR(19),
	CREATE_DATE		TIMESTAMP with time zone NOT NULL DEFAULT NOW()
);

CREATE TABLE W_LOCALITY_ALIAS(
	ID 			bigserial NOT NULL PRIMARY KEY,
	LOCALITY_ID		bigint NOT NULL references W_LOCALITY(ID),
	KLADR_ID		VARCHAR(19),
	NAME			character varying(64) NOT NULL,
	CREATE_DATE		TIMESTAMP with time zone NOT NULL DEFAULT NOW()
);

INSERT INTO W_LOCALITY_TYPE(NAME) 
	SELECT DISTINCT 
		TRIM(TYPE) 
	FROM 
		KLADR_BASE.W_KLADR_TBL 
	UNION 
	SELECT 
		TRIM(TYPE) 
	FROM 
		KLADR_BASE.W_STREET_TBL 
	UNION 
	SELECT 
		TRIM(C1) 
	FROM 
		KLADR_BASE.W_DOMA_TBL;

INSERT INTO W_LOCALITY(NAME, W_LOCALITY_TYPE_ID, KLADR_ID)
	SELECT 
		NAME, 
		(SELECT ID FROM W_LOCALITY_TYPE WHERE NAME=TRIM(KLADR_BASE.W_KLADR_TBL.TYPE)) AS type_id,
		TRIM(CODE) 
	FROM 
		(SELECT 
			TRIM(substring(CODE FROM 1 FOR 11)) bc, 
			min(cast(substring(CODE FROM 12 FOR 2) as integer)) ac 
		FROM 
			KLADR_BASE.W_KLADR_TBL group by TRIM(substring(CODE FROM 1 FOR 11))) T1 INNER JOIN
		KLADR_BASE.W_KLADR_TBL ON 
			TRIM(KLADR_BASE.W_KLADR_TBL.CODE)=
				CONCAT(
					TRIM(T1.BC), 
					TRIM(TO_CHAR(T1.AC, '09')));

CREATE INDEX W_LOCALITY_KLADR_ID on W_LOCALITY(KLADR_ID);

INSERT INTO W_LOCALITY_ALIAS(NAME, W_LOCALITY_ID, KLADR_ID) 
	SELECT 
		NAME,
		(SELECT ID FROM W_LOCALITY WHERE KLADR_ID=CONCAT(TRIM(T1.BC), TRIM(TO_CHAR(T1.AC, '09')))),
		TRIM(CODE)
	FROM 
		(SELECT 
			substring(CODE FROM 1 FOR 11) bc, 
			min(cast(substring(CODE FROM 12 FOR 2) as integer)) ac 
		FROM 
			KLADR_BASE.W_KLADR_TBL group by substring(CODE FROM 1 FOR 11)) T1 INNER JOIN
		KLADR_BASE.W_KLADR_TBL ON (
			TRIM(substring(KLADR_BASE.W_KLADR_TBL.CODE FROM 1 FOR 11))=TRIM(T1.BC) AND 
			cast(substring(CODE FROM 12 FOR 2) as integer)<>T1.ac);

INSERT INTO W_LOCALITY(NAME, W_LOCALITY_TYPE_ID, KLADR_ID)
	SELECT 
		NAME, 
		(SELECT ID FROM W_LOCALITY_TYPE WHERE NAME=TRIM(KLADR_BASE.W_STREET_TBL.TYPE)) AS type_id,
		TRIM(CODE) 
	FROM 
		(SELECT 
			TRIM(substring(CODE FROM 1 FOR 15)) bc, 
			min(cast(substring(CODE FROM 16 FOR 2) as integer)) ac 
		FROM 
			KLADR_BASE.W_STREET_TBL group by TRIM(substring(CODE FROM 1 FOR 15))) T1 INNER JOIN
			KLADR_BASE.W_STREET_TBL ON 
				TRIM(KLADR_BASE.W_STREET_TBL.CODE)=
					CONCAT(
						TRIM(T1.BC), 
						TRIM(TO_CHAR(T1.AC, '09')));		

INSERT INTO W_LOCALITY_ALIAS(NAME, W_LOCALITY_ID, KLADR_ID) 
	SELECT 
		NAME,
		(SELECT ID FROM W_LOCALITY WHERE KLADR_ID=CONCAT(TRIM(T1.BC), TRIM(TO_CHAR(T1.AC, '09')))),
		TRIM(CODE)
	FROM 
		(SELECT 
			substring(CODE FROM 1 FOR 15) bc, 
			min(cast(substring(CODE FROM 16 FOR 2) as integer)) ac 
		FROM 
			KLADR_BASE.W_STREET_TBL group by substring(CODE FROM 1 FOR 15)) T1 INNER JOIN
		KLADR_BASE.W_STREET_TBL ON (
			TRIM(substring(KLADR_BASE.W_STREET_TBL.CODE FROM 1 FOR 15))=TRIM(T1.BC) AND 
			cast(substring(CODE FROM 16 FOR 2) as integer)<>T1.ac);

DROP INDEX W_LOCALITY_KLADR_ID;

INSERT INTO W_LOCALITY(NAME, W_LOCALITY_TYPE_ID, KLADR_ID)
	WITH RECURSIVE T1 as (
		SELECT
			string_to_array(HOUSE, '-') as HOUSE,
			TYPE,
			CODE
		FROM 
			(SELECT 
				unnest(string_to_array(HOUSE, ',')) as HOUSE, 
				(SELECT ID FROM W_LOCALITY_TYPE WHERE NAME=TYPE) as TYPE, 
				CODE as CODE 
			FROM 
				kladr_base.w_doma_tbl) T10
		WHERE
			HOUSE~'^[0-9]+-[0-9]+$'),
	T2(CODE, TYPE, HOUSE) AS (
		SELECT 
			CODE,
			TYPE,
			HOUSE[1]::INT AS HOUSE
		FROM
			T1
		UNION ALL
		SELECT 
			T2.CODE,
			T2.TYPE,
			T2.HOUSE + 1 AS HOUSE
		FROM
			T1 INNER JOIN T2 ON T2.CODE=T1.CODE
		WHERE
		    	T2.HOUSE >= T1.HOUSE[1]::INT AND
			(T2.HOUSE + 1) <= T1.HOUSE[2]::INT),
	T3 as (
		SELECT
			string_to_array(substring(HOUSE from '[0-9]+-[0-9]+'), '-') as HOUSE,
			TYPE,
			CODE
		FROM 
			(SELECT 
				unnest(string_to_array(HOUSE, ',')) as HOUSE, 
				(SELECT ID FROM W_LOCALITY_TYPE WHERE NAME=TYPE) as TYPE, 
				CODE as CODE 
			FROM 
				kladr_base.w_doma_tbl) T10
		WHERE
			HOUSE~'^(Н|Ч)\([0-9]+-[0-9]+\)$'),
	T4(CODE, TYPE, HOUSE) AS (
		SELECT 
			CODE,
			TYPE,
			HOUSE[1]::INT AS HOUSE
		FROM
			T3
		UNION ALL
		SELECT 
			T4.CODE,
			T4.TYPE,
			T4.HOUSE + 2 AS HOUSE
		FROM
			T3 INNER JOIN T4 ON T4.CODE=T3.CODE
		WHERE
			T4.HOUSE >= T3.HOUSE[1]::INT AND
			(T4.HOUSE + 2) <= T3.HOUSE[2]::INT) 	
	SELECT 
		CODE,
		TYPE,
		to_char(HOUSE, '999') 
	FROM 
		T2
	UNION ALL
	SELECT 
		CODE,
		TYPE,
		to_char(HOUSE, '999')
	FROM
		T4
	UNION ALL
	SELECT
		CODE,
		TYPE,
		HOUSE		
	FROM	
		(SELECT 
			unnest(string_to_array(HOUSE, ',')) as HOUSE, 
			(SELECT ID FROM W_LOCALITY_TYPE WHERE NAME=TYPE) as TYPE, 
			CODE as CODE 
		FROM 
			kladr_base.w_doma_tbl) T1
	WHERE
		HOUSE!~'^[0-9]+-[0-9]+$' AND
        	HOUSE!~'^(Н|Ч)\([0-9]+-[0-9]+\)$';	

CREATE INDEX W_LOCALITY_KLADR_ID_TMP_IDX on W_LOCALITY(
	char_length(KLADR_ID), 
	substring(KLADR_ID FROM 3 FOR 9), 
	substring(KLADR_ID FROM 1 FOR 2));

UPDATE W_LOCALITY SET 
	PARENT_ID=(
		SELECT 
			ID
		FROM 
			W_LOCALITY T1
		WHERE 
			char_length(T1.KLADR_ID)=13 AND 
			substring(T1.KLADR_ID FROM 3 FOR 9)=lpad('', 9, '0') AND
			substring(T1.KLADR_ID FROM 1 FOR 2)=substring(W_LOCALITY.KLADR_ID FROM 1 FOR 2))
	WHERE
		char_length(W_LOCALITY.KLADR_ID)=13 AND 
		substring(W_LOCALITY.KLADR_ID FROM 3 FOR 3)<>lpad('', 3, '0') AND
		substring(W_LOCALITY.KLADR_ID FROM 6 FOR 6)=lpad('', 6, '0');
	
drop index W_LOCALITY_KLADR_ID_TMP_IDX;

create index W_LOCALITY_KLADR_ID_TMP_IDX on W_LOCALITY(
	char_length(KLADR_ID), 
	substring(KLADR_ID FROM 6 FOR 6), 
	substring(KLADR_ID FROM 1 FOR 5));

UPDATE W_LOCALITY SET 
	PARENT_ID=(
		SELECT 
			ID 
		FROM 
			W_LOCALITY T1
		WHERE 
			char_length(T1.KLADR_ID)=13 AND 
			substring(T1.KLADR_ID FROM 6 FOR 6)=lpad('', 6, '0') AND
			substring(T1.KLADR_ID FROM 1 FOR 5)=substring(W_LOCALITY.KLADR_ID FROM 1 FOR 5))
	WHERE
		char_length(W_LOCALITY.KLADR_ID)=13 AND 
		substring(W_LOCALITY.KLADR_ID FROM 6 FOR 3)<>lpad('', 3, '0') AND
		substring(W_LOCALITY.KLADR_ID FROM 9 FOR 3)=lpad('', 3, '0');

drop index W_LOCALITY_KLADR_ID_TMP_IDX;

create index W_LOCALITY_KLADR_ID_TMP_IDX on W_LOCALITY(
	char_length(KLADR_ID), 
	substring(KLADR_ID FROM 9 FOR 3), 
	substring(KLADR_ID FROM 1 FOR 8));

UPDATE W_LOCALITY SET 
	PARENT_ID=(
		SELECT 
			ID 
		FROM 
			W_LOCALITY T1
		WHERE 
			char_length(T1.KLADR_ID)=13 AND 
			substring(T1.KLADR_ID FROM 9 FOR 3)=lpad('', 3, '0') AND
			substring(T1.KLADR_ID FROM 1 FOR 8)=substring(W_LOCALITY.KLADR_ID FROM 1 FOR 8))
	WHERE
		char_length(W_LOCALITY.KLADR_ID)=13 AND 
		substring(W_LOCALITY.KLADR_ID FROM 9 FOR 3)<>lpad('', 3, '0');

drop index W_LOCALITY_KLADR_ID_TMP_IDX;

create index W_LOCALITY_KLADR_ID_TMP_IDX on W_LOCALITY(
	char_length(KLADR_ID), 
	substring(KLADR_ID FROM 1 FOR 11));

UPDATE W_LOCALITY SET 
	PARENT_ID=(
		SELECT 
			ID 
		FROM 
			W_LOCALITY T1
		WHERE 
			char_length(T1.KLADR_ID)=13 AND 
			substring(T1.KLADR_ID FROM 1 FOR 11)=substring(W_LOCALITY.KLADR_ID FROM 1 FOR 11))
	WHERE
		char_length(W_LOCALITY.KLADR_ID)=17 AND 
		substring(W_LOCALITY.KLADR_ID FROM 12 FOR 4)<>lpad('', 4, '0');

drop index W_LOCALITY_KLADR_ID_TMP_IDX;

create index W_LOCALITY_KLADR_ID_TMP_IDX on W_LOCALITY(
	char_length(KLADR_ID), 
	substring(KLADR_ID FROM 1 FOR 15));

UPDATE W_LOCALITY SET 
	PARENT_ID=(
		SELECT 
			ID 
		FROM 
			W_LOCALITY T1
		WHERE 
			char_length(T1.KLADR_ID)=17 AND 
			substring(T1.KLADR_ID FROM 1 FOR 15)=substring(W_LOCALITY.KLADR_ID FROM 1 FOR 15))
	WHERE
		char_length(W_LOCALITY.KLADR_ID)=19 AND 
		substring(W_LOCALITY.KLADR_ID FROM 16 FOR 4)<>lpad('', 4, '0');

drop index W_LOCALITY_KLADR_ID_TMP_IDX;

create index W_LOCALITY_KLADR_ID_TMP_IDX on W_LOCALITY(
	char_length(KLADR_ID), 
	substring(KLADR_ID FROM 1 FOR 11));

UPDATE W_LOCALITY SET 
	PARENT_ID=(
		SELECT 
			ID 
		FROM 
			W_LOCALITY T1
		WHERE 
			char_length(T1.KLADR_ID)=13 AND 
			substring(T1.KLADR_ID FROM 1 FOR 11)=substring(W_LOCALITY.KLADR_ID FROM 1 FOR 11))
	WHERE
		char_length(W_LOCALITY.KLADR_ID)=19 AND 
		substring(W_LOCALITY.KLADR_ID FROM 16 FOR 4)<>lpad('', 4, '0') AND
		PARENT_ID IS NULL;

drop index W_LOCALITY_KLADR_ID_TMP_IDX;
create index W_LOCALITY_PARENT_ID on W_LOCALITY(PARENT_ID);
CREATE INDEX W_LOCALITY_NAME ON W_LOCALITY(NAME);	
