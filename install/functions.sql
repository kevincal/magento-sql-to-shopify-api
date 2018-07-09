/*
SQL Functions for Data Clean-up and other Tasks during Shopify Migration
 */

## ##
DELIMITER ;;
DROP FUNCTION IF EXISTS `STRIP_NON_DIGIT`;;

CREATE FUNCTION `STRIP_NON_DIGIT`(input VARCHAR(255)) RETURNS VARCHAR(255) CHARSET utf8
READS SQL DATA
BEGIN
	DECLARE output VARCHAR(255) DEFAULT '';
	DECLARE iterator INT DEFAULT 1;
	DECLARE lastDigit INT DEFAULT 1;
	DECLARE len INT;

	SET len = LENGTH(input) + 1;
	WHILE iterator < len DO
		-- skip past all digits
		SET lastDigit = iterator;

		WHILE ORD(SUBSTRING(input, iterator, 1)) BETWEEN 48 AND 57 AND iterator < len DO
			SET iterator = iterator + 1;
		END WHILE;

		IF iterator != lastDigit THEN
			SET output = CONCAT(output, SUBSTRING(input, lastDigit, iterator -lastDigit));
		END IF;

		WHILE ORD(SUBSTRING(input, iterator, 1)) NOT BETWEEN 48 AND 57 AND
			iterator < len DO
			SET iterator = iterator + 1;
		END WHILE;
	END WHILE;

	RETURN output;
END;;

DELIMITER ;
## ##