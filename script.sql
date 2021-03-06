
CREATE TABLE W_LOCALITY_TYPE(
	ID 			bigserial NOT NULL PRIMARY KEY,
	NAME			character varying(64) DEFAULT NULL UNIQUE,
	CREATE_DATE		TIMESTAMP with time zone NOT NULL DEFAULT NOW()
);

CREATE TABLE W_LOCALITY(
	ID 			bigserial NOT NULL PRIMARY KEY,
	PARENT_ID		bigint,
	NAME			character varying(64) DEFAULT NULL,
	W_LOCALITY_TYPE_ID 	bigint NOT NULL references W_LOCALITY_TYPE(ID),
	KLADR_ID		VARCHAR(19),
	CREATE_DATE		TIMESTAMP with time zone NOT NULL DEFAULT NOW()
);

CREATE TABLE W_LOCALITY_ALIAS(
	ID 			bigserial NOT NULL PRIMARY KEY,
	W_LOCALITY_ID		bigint NOT NULL references W_LOCALITY(ID),
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

INSERT INTO W_LOCALITY(KLADR_ID, W_LOCALITY_TYPE_ID, NAME)
	WITH RECURSIVE T1 as (
		SELECT
			row_number() over() as RN,
			string_to_array(HOUSE, '-') as HOUSE,
			(SELECT ID FROM W_LOCALITY_TYPE WHERE NAME=TYPE) as TYPE,
			CODE
		FROM 
			(SELECT 
				unnest(string_to_array(HOUSE, ',')) as HOUSE, 
				TYPE AS TYPE,
				CODE as CODE 
			FROM 
				kladr_base.w_doma_tbl) T10
		WHERE
			HOUSE~'^[0-9]+-[0-9]+$'),
	T2(RN, CODE, TYPE, HOUSE) AS (
		SELECT
			RN,
			CODE,
			TYPE,
			HOUSE[1]::INT AS HOUSE
		FROM
			T1
		UNION ALL
		SELECT 
			T2.RN,
			T2.CODE,
			T2.TYPE,
			T2.HOUSE + 1 AS HOUSE
		FROM
			T1 INNER JOIN T2 ON T2.RN=T1.RN
		WHERE
		    T2.HOUSE >= T1.HOUSE[1]::INT AND
			(T2.HOUSE + 1) <= T1.HOUSE[2]::INT),
	T3 as (
		SELECT
			row_number() over() as RN,
			string_to_array(substring(HOUSE from '[0-9]+-[0-9]+'), '-') as HOUSE,
			(SELECT ID FROM W_LOCALITY_TYPE WHERE NAME=TYPE) as TYPE, 
			CODE
		FROM 
			(SELECT 
				unnest(string_to_array(HOUSE, ',')) as HOUSE, 
				TYPE as TYPE, 
				CODE as CODE 
			FROM 
				kladr_base.w_doma_tbl) T10
		WHERE
			HOUSE~'^(Н|Ч)\([0-9]+-[0-9]+\)$'),
	T4(RN, CODE, TYPE, HOUSE) AS (
		SELECT
			RN,
			CODE,
			TYPE,
			HOUSE[1]::INT AS HOUSE
		FROM
			T3
		UNION ALL
		SELECT 
			T4.RN,
			T4.CODE,
			T4.TYPE,
			T4.HOUSE + 2 AS HOUSE
		FROM
			T3 INNER JOIN T4 ON T4.RN=T3.RN
		WHERE
		    	T4.HOUSE >= T3.HOUSE[1]::INT AND
			(T4.HOUSE + 2) <= T3.HOUSE[2]::INT) 	
	SELECT 
		CODE,
		TYPE,
		to_char(HOUSE, '99999') 
	FROM 
		T2
	UNION ALL
	SELECT 
		CODE,
		TYPE,
		to_char(HOUSE, '99999')
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


CREATE OR REPLACE FUNCTION get_locality_level(v_code varchar) 
RETURNS integer AS $$
DECLARE
	v_res			integer := NULL;
BEGIN
	IF v_code IS NOT NULL THEN
		CASE 
			WHEN char_length(v_code)=13 THEN
			BEGIN
				v_res := 0;
			
				IF substring(v_code from 1 for 2)<>lpad('', 2, '0') THEN
					v_res := v_res + 1;
				END IF;
			
				IF substring(v_code from 3 for 3)<>lpad('', 3, '0') THEN
					v_res := v_res + 1;
				END IF;
			
				IF substring(v_code from 6 for 3)<>lpad('', 3, '0') THEN
					v_res := v_res + 1;
				END IF;
			
				IF substring(v_code from 9 for 3)<>lpad('', 3, '0') THEN
					v_res := v_res + 1;
				END IF;
			END;
			
			WHEN char_length(v_code)=17 THEN
			BEGIN
				v_res := 0;
			
				IF substring(v_code from 1 for 2)<>lpad('', 2, '0') THEN
					v_res := v_res + 1;
				END IF;
			
				IF substring(v_code from 3 for 3)<>lpad('', 3, '0') THEN
					v_res := v_res + 1;
				END IF;
			
				IF substring(v_code from 6 for 3)<>lpad('', 3, '0') THEN
					v_res := v_res + 1;
				END IF;
			
				IF substring(v_code from 9 for 3)<>lpad('', 3, '0') THEN
					v_res := v_res + 1;
				END IF;
			
				IF substring(v_code from 12 for 4)<>lpad('', 4, '0') THEN
					v_res := v_res + 1;
				END IF;
			END;
		
			WHEN char_length(v_code)=19 THEN
			BEGIN
				v_res := 0;
			
				IF substring(v_code from 1 for 2)<>lpad('', 2, '0') THEN
					v_res := v_res + 1;
				END IF;
			
				IF substring(v_code from 3 for 3)<>lpad('', 3, '0') THEN
					v_res := v_res + 1;
				END IF;
			
				IF substring(v_code from 6 for 3)<>lpad('', 3, '0') THEN
					v_res := v_res + 1;
				END IF;
			
				IF substring(v_code from 9 for 3)<>lpad('', 3, '0') THEN
					v_res := v_res + 1;
				END IF;
			
				IF substring(v_code from 12 for 4)<>lpad('', 4, '0') THEN
					v_res := v_res + 1;
				END IF;
			
				IF substring(v_code from 16 for 4)<>lpad('', 4, '0') THEN
					v_res := v_res + 1;
				END IF;
			END;
			ELSE
				v_res := NULL;
		END CASE;
	END IF;
	
	RETURN v_res;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE UNIQUE INDEX W_LOCALITY_PARENT_ID_IDX on W_LOCALITY(ID, PARENT_ID);
CREATE UNIQUE INDEX W_LOCALITY_NAME_IDX ON W_LOCALITY(NAME, ID);	
CREATE UNIQUE INDEX W_LOCALITY_NULL_PARENT_ID_IDX on W_LOCALITY(ID) WHERE PARENT_ID IS NULL;

CREATE UNIQUE INDEX W_LOCALITY_CODE_LEVEL_IDX ON W_LOCALITY(LOWER(NAME), get_locality_level(KLADR_ID), ID);
CREATE UNIQUE INDEX W_LOCALITY_PARENT_TYPE_NAME_IDX ON W_LOCALITY(PARENT_ID, W_LOCALITY_TYPE_ID, LOWER(NAME), ID);
CREATE UNIQUE INDEX W_LOCALITY_NAME_IDX ON W_LOCALITY(LOWER(NAME), ID);
CREATE UNIQUE INDEX W_LOCALITY_TYPE_IDX ON W_LOCALITY_TYPE(ID, LOWER(NAME));



CREATE OR REPLACE VIEW W_LOCALITY_VIEW(ID, PREFIX, NAME, PARENT_ID) AS
	SELECT 
		W_LOCALITY.ID AS ID,
		W_LOCALITY_TYPE.NAME AS PREFIX,
		W_LOCALITY.NAME AS NAME,
		W_LOCALITY.PARENT_ID AS PARENT_ID
	FROM
		W_LOCALITY INNER JOIN 
		W_LOCALITY_TYPE ON W_LOCALITY_TYPE.ID=W_LOCALITY.W_LOCALITY_TYPE_ID;


CREATE OR REPLACE FUNCTION get_kladr_full_address(v_locality_id bigint) 
RETURNS varchar AS $$
DECLARE
	v_res			varchar;
BEGIN
	WITH RECURSIVE T(ID, LEVEL) AS (
		SELECT v_locality_id AS ID, 1 AS LEVEL
	UNION ALL
		SELECT W_LOCALITY.PARENT_ID, T.LEVEL + 1 FROM T INNER JOIN W_LOCALITY ON T.ID=W_LOCALITY.ID WHERE W_LOCALITY.PARENT_ID IS NOT NULL
	)
	SELECT 
		array_to_string(array_agg(concat(trim(w_locality_type.name), ' ', trim(w_locality.name)) ORDER BY LEVEL DESC), ',') into v_res
	FROM 
		T INNER JOIN 
		W_LOCALITY ON T.ID=W_LOCALITY.ID INNER JOIN 
		W_LOCALITY_TYPE ON W_LOCALITY_TYPE.ID=w_locality.w_locality_type_id;

	RETURN v_res;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_kladr_address(v_address varchar) 
RETURNS refcursor AS $$
DECLARE
	v_res			refcursor;
BEGIN	
	
	OPEN v_res FOR WITH RECURSIVE T1 AS (
		select 
			TRIM(unnest(string_to_array(v_address, ','))) as PART),
	T2 AS (
		SELECT 
			row_number() over() as RN,
			string_to_array(PART, ' ') AS PART 
		FROM 
			T1 
		WHERE 
			array_length(string_to_array(PART, ' '), 1) = 2),
	T2_1 AS (
		SELECT COUNT(*) AS CNT FROM T1),
	T2_2 AS (
		SELECT COUNT(*) AS CNT FROM T2),
	T2_3 AS (
		SELECT 
			T2.RN AS RN,
			W_LOCALITY.ID AS ID,
			W_LOCALITY_TYPE.NAME AS PREFIX,
			W_LOCALITY.NAME AS NAME,
			W_LOCALITY.PARENT_ID AS PARENT_ID
		FROM
			W_LOCALITY INNER JOIN 
			W_LOCALITY_TYPE ON W_LOCALITY_TYPE.ID=W_LOCALITY.W_LOCALITY_TYPE_ID, T2, T2_1, T2_2
		WHERE
			get_locality_level(W_LOCALITY.KLADR_ID) < 3 AND
			((LOWER(W_LOCALITY_TYPE.NAME)=LOWER(TRIM(T2.PART[1])) AND
				LOWER(W_LOCALITY.NAME)=LOWER(TRIM(T2.PART[2]))) OR 
			(LOWER(W_LOCALITY_TYPE.NAME)=LOWER(TRIM(T2.PART[2])) AND
				LOWER(W_LOCALITY.NAME)=LOWER(TRIM(T2.PART[1])))) AND
			T2_1.CNT=T2_2.CNT),
	T3 AS (
		SELECT
			T2_3.ID AS ID,
			T2_3.PREFIX AS PREFIX,
			T2_3.NAME AS NAME,
			T2_3.PARENT_ID AS PARENT_ID
		FROM
			T2_3),
	T4(ID, PARENT_ID, LEVEL) AS (
		SELECT 
			ID,
			PARENT_ID,
			1 AS LEVEL
		FROM
			T3
		UNION ALL
		SELECT
			T4.ID AS ID,
			W_LOCALITY.PARENT_ID AS PARENT_ID,
			T4.LEVEL + 1 AS LEVEL
		FROM
			W_LOCALITY INNER JOIN 
			T4 ON T4.PARENT_ID=W_LOCALITY.ID
		WHERE
			T4.PARENT_ID IS NOT NULL AND
			T4.PARENT_ID IN (SELECT ID FROM T3)),
	T5(ID, LEVEL) AS (	
		SELECT 
			ID, 
			MAX(LEVEL) AS LEVEL
		FROM 	
			T4
		WHERE
			PARENT_ID IN (SELECT ID FROM T3)
		GROUP BY ID),
	T6 AS (	
		SELECT COUNT(*) AS CNT FROM T3),
	T7 AS (
		SELECT
			T5.ID AS ID,
			T5.LEVEL AS LEVEL
		FROM
			W_LOCALITY INNER JOIN 
			T5 ON T5.ID=W_LOCALITY.ID,
			T6
		WHERE 
			(T6.CNT > 1 AND (SELECT ID FROM T3 WHERE T3.ID=W_LOCALITY.PARENT_ID) IS NOT NULL) OR
			T6.CNT=1),	
	T8 AS (
		SELECT
			ID,
			LEVEL
		FROM
			T7
		WHERE
			(SELECT ID FROM T4 WHERE PARENT_ID=T7.ID LIMIT 1) IS NULL),		
	T9(ROOT_ID, ID, PARENT_ID, LEVEL) AS (
		SELECT
			T8.ID AS ROOT_ID,
			W_LOCALITY.ID AS ID,
			W_LOCALITY.PARENT_ID AS PARENT_ID,
			T8.LEVEL AS LEVEL
		FROM
			T8 INNER JOIN 
			W_LOCALITY ON T8.ID=W_LOCALITY.ID
		UNION ALL
		SELECT
			T9.ROOT_ID AS ROOT_ID,
			W_LOCALITY.ID AS ID,
			W_LOCALITY.PARENT_ID AS PARENT_ID,
			T9.LEVEL - 1 AS LEVEL
		FROM
			W_LOCALITY INNER JOIN 
			T9 ON W_LOCALITY.ID=T9.PARENT_ID
		WHERE
			T9.PARENT_ID IS NOT NULL),
	T9_1 AS (		
		SELECT
			RN,
			PART
		FROM
			T2
		WHERE
			T2.RN NOT IN (SELECT RN FROM T2_3 INNER JOIN T9 ON T9.ID=T2_3.ID)),
	T9_2 AS (
		SELECT 
			MAX(LEVEL) AS LEVEL
		FROM
			T9),
	T9_3 AS (
		SELECT 
			T9.ROOT_ID AS ROOT_ID,
			ID AS ID,
			T9.LEVEL + 1 AS LEVEL
		FROM
			T9, T9_2
		WHERE
			T9.LEVEL=T9_2.LEVEL),
	T9_4 AS (
		SELECT 
			T9_1.RN AS RN,
			T9_3.ROOT_ID AS ROOT_ID,
			W_LOCALITY.ID AS ID,
			W_LOCALITY.PARENT_ID AS PARENT_ID,
			T9_3.LEVEL AS LEVEL
		FROM
			W_LOCALITY INNER JOIN 
			W_LOCALITY_TYPE ON W_LOCALITY_TYPE.ID=W_LOCALITY.W_LOCALITY_TYPE_ID INNER JOIN
			T9_3 ON W_LOCALITY.PARENT_ID=T9_3.ID, T9_1 
		WHERE
			((LOWER(W_LOCALITY_TYPE.NAME)=LOWER(TRIM(T9_1.PART[1])) AND
				LOWER(W_LOCALITY.NAME)=LOWER(TRIM(T9_1.PART[2]))) OR 
			(LOWER(W_LOCALITY_TYPE.NAME)=LOWER(TRIM(T9_1.PART[2])) AND
				LOWER(W_LOCALITY.NAME)=LOWER(TRIM(T9_1.PART[1]))))),
	T9_5 AS (	
		SELECT
			T9.ROOT_ID AS ROOT_ID,
			T9.ID AS ID,
			T9.PARENT_ID AS PARENT_ID,
			T9.LEVEL AS LEVEL
		FROM 
			T9
		UNION ALL
		SELECT
			T9_4.ROOT_ID AS ROOT_ID,
			T9_4.ID AS ID,
			T9_4.PARENT_ID AS PARENT_ID,
			T9_4.LEVEL AS LEVEL
		FROM 
			T9_4),
	T9_6 AS (
		SELECT
			RN,
			PART
		FROM
			T2
		WHERE
			T2.RN NOT IN (SELECT RN FROM T2_3 INNER JOIN T9 ON T9.ID=T2_3.ID)),
	T9_7 AS (
		SELECT 
			T9_6.RN AS RN,
			T9_4.ROOT_ID AS ROOT_ID,
			W_LOCALITY.ID AS ID,
			W_LOCALITY.PARENT_ID AS PARENT_ID,
			T9_4.LEVEL + 1 AS LEVEL
		FROM
			W_LOCALITY INNER JOIN 
			W_LOCALITY_TYPE ON W_LOCALITY_TYPE.ID=W_LOCALITY.W_LOCALITY_TYPE_ID INNER JOIN
			T9_4 ON W_LOCALITY.PARENT_ID=T9_4.ID, T9_6 
		WHERE
			((LOWER(W_LOCALITY_TYPE.NAME)=LOWER(TRIM(T9_6.PART[1])) AND
				LOWER(W_LOCALITY.NAME)=LOWER(TRIM(T9_6.PART[2]))) OR 
			(LOWER(W_LOCALITY_TYPE.NAME)=LOWER(TRIM(T9_6.PART[2])) AND
				LOWER(W_LOCALITY.NAME)=LOWER(TRIM(T9_6.PART[1]))))),
	T9_8 AS (
		SELECT
			T9_5.ROOT_ID AS ROOT_ID,
			T9_5.ID AS ID,
			T9_5.PARENT_ID AS PARENT_ID,
			T9_5.LEVEL AS LEVEL
		FROM 
			T9_5
		UNION ALL
		SELECT
			T9_7.ROOT_ID AS ROOT_ID,
			T9_7.ID AS ID,
			T9_7.PARENT_ID AS PARENT_ID,
			T9_7.LEVEL AS LEVEL
		FROM 
			T9_7),
	T9_9 AS (
		SELECT
			ROOT_ID,
			MAX(LEVEL) AS LEVEL
		FROM
			T9_8
		GROUP BY ROOT_ID),
	T9_10(ROOT_ID, ID, PARENT_ID, LEVEL) AS (
		SELECT
			T9_8.ROOT_ID AS ROOT_ID,
			T9_8.ID AS ID,
			T9_8.PARENT_ID AS PARENT_ID,
			T9_8.LEVEL AS LEVEL
		FROM
			T9_8 INNER JOIN 
			T9_9 ON (T9_9.ROOT_ID=T9_8.ROOT_ID AND T9_9.LEVEL=T9_8.LEVEL)
		UNION ALL
		SELECT
			T9_10.ROOT_ID AS ROOT_ID,
			T9_8.ID AS ID,
			T9_8.PARENT_ID AS PARENT_ID,
			T9_8.LEVEL AS LEVEL
		FROM
			T9_10 INNER JOIN
			T9_8 ON (T9_10.PARENT_ID=T9_8.ID AND T9_10.ROOT_ID=T9_8.ROOT_ID)),
	T10 AS (
		SELECT 
			1 AS ID 
		FROM 
			T6 
		WHERE 
			(SELECT COUNT(*) FROM T9_10)=(SELECT COUNT(*) FROM T1))
	SELECT 
		T9_10.ROOT_ID as ROOT_ID,
		T9_10.ID AS ID,
		T9_10.PARENT_ID AS PARENT_ID,
		T9_10.LEVEL AS LEVEL,
		W_LOCALITY_VIEW.NAME AS NAME,
		W_LOCALITY_VIEW.PREFIX AS PREFIX
	FROM 
		T9_10 INNER JOIN W_LOCALITY_VIEW ON W_LOCALITY_VIEW.ID=T9_10.ID, T10 
	WHERE 
		T10.ID=1;
		
	RETURN v_res;
END;
$$ LANGUAGE plpgsql;

ALTER TABLE W_LOCALITY ADD COORD POINT DEFAULT NULL;


CREATE OR REPLACE FUNCTION update_yandex_gps_coord(v_cnt integer) 
RETURNS integer AS $$
DECLARE
	v_res		integer;
BEGIN	
	WITH T1 AS (
		SELECT 
			ID 
		FROM
			W_LOCALITY_TYPE
		WHERE
			LOWER(NAME)='дом'),
	T2 AS (
		SELECT
			W_LOCALITY.ID AS ID,
			(SELECT 
				xpath(
					'/xmlns1:ymaps/xmlns1:GeoObjectCollection/xmlns2:featureMember/xmlns1:GeoObject/xmlns2:Point/xmlns2:pos/text()'::varchar, 
					"content"::xml, 
					ARRAY[
						ARRAY['xmlns1', 'http://maps.yandex.ru/ymaps/1.x'], 
						ARRAY['xmlns2', 'http://www.opengis.net/gml']]) COORD
			FROM 
				http_get(
					concat(
						'http://geocode-maps.yandex.ru/1.x/?geocode=', 
						get_kladr_full_address(W_LOCALITY.ID)))) AS CONTENT 
		FROM
			W_LOCALITY, T1
		WHERE
			W_LOCALITY_TYPE_ID=T1.ID AND
			W_LOCALITY.COORD IS NULL 
		LIMIT v_cnt),
	T3 AS (
		SELECT
			T2.ID AS ID,
			unnest(T2.CONTENT) AS COORD
		FROM
			T2),
	T4 AS (	
		SELECT 
			ID, 
			string_to_array(T3.COORD::varchar, ' ') AS COORD 
		FROM T3),
	T5 AS (
		SELECT 
			ID,
			POINT(COORD[1]::double precision, COORD[2]::double precision) AS COORD
		FROM
			T4)
	UPDATE W_LOCALITY SET COORD=T6.COORD FROM (SELECT ID, COORD FROM T5) T6 WHERE W_LOCALITY.ID=T6.ID;

	GET DIAGNOSTICS v_res = ROW_COUNT;

	RETURN v_res;
END;
$$ LANGUAGE plpgsql;
	
