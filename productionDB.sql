CREATE TABLE `고객` (
	`id` INT(11) UNSIGNED ZEROFILL PRIMARY KEY AUTO_INCREMENT,
	`기업명` VARCHAR(60) UNIQUE NOT NULL,
	`사업자등록번호` VARCHAR(10) UNIQUE NOT NULL,
	`전화번호` VARCHAR(20) NOT NULL,
	`email` VARCHAR(320) NOT NULL,
	`주소` VARCHAR(255) NOT NULL,
	`FAX` VARCHAR(50)
);

CREATE TABLE `제품` (
	`id` INT(11)	UNSIGNED ZEROFILL PRIMARY KEY AUTO_INCREMENT,
	`제품명` VARCHAR(60) NOT NULL,
	`정가` INT NOT NULL CHECK (`정가`>=0)
);

CREATE TABLE `제조공장` (
	`id`	INT(3) UNSIGNED ZEROFILL PRIMARY KEY AUTO_INCREMENT,
	`공장명`	VARCHAR(60)	NOT NULL,
	`주소`	VARCHAR(255)	NOT NULL,
	`연락처`	VARCHAR(20)	NOT NULL
);

CREATE TABLE `원자재` (
	`id`	INT(11)	UNSIGNED ZEROFILL PRIMARY KEY AUTO_INCREMENT,
	`구분`	TINYINT	UNSIGNED NOT NULL CHECK (`구분` IN (1,2)),
	`원자재명`	VARCHAR(60)	NOT NULL
);

CREATE TABLE `원자재거래처` (
	`id`	INT(3)	UNSIGNED ZEROFILL PRIMARY KEY AUTO_INCREMENT,
	`거래처명`	VARCHAR(60)	NOT NULL,
	`주소`	VARCHAR(255)	NOT NULL,
	`전화번호`	VARCHAR(20)	NOT NULL
);

CREATE TABLE `원자재보관현황` (
	`id`	INT(11)	UNSIGNED ZEROFILL NOT NULL,
	`제조공장_id` INT(3) UNSIGNED ZEROFILL NOT NULL,
	`예정필요량` INT NOT NULL DEFAULT 0 CHECK(`예정필요량`>=0),
	`예정확보량` INT NOT NULL DEFAULT 0 CHECK(`예정확보량`>=0),
	`보관량`	INT NOT NULL DEFAULT 0 CHECK(`보관량`>=0),
	FOREIGN KEY (`id`) REFERENCES `원자재`(`id`) ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY (`제조공장_id`) REFERENCES `제조공장`(`id`) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE `택배업체` (
	`id`	INT(3)	UNSIGNED ZEROFILL PRIMARY KEY AUTO_INCREMENT,
	`업체명`	VARCHAR(60)	UNIQUE NOT NULL,
	`연락처`	VARCHAR(20)	NOT NULL,
	`택배비용`	INT	NOT NULL
);

CREATE TABLE `제품별필요원자재` (
	`제품_id`	INT(11)	UNSIGNED ZEROFILL NOT NULL,
	`원자재_id`	INT(11)	UNSIGNED ZEROFILL NOT NULL,
	`필요량`	INT	NOT NULL CHECK (`필요량`>=0),
	FOREIGN KEY(`제품_id`) REFERENCES `제품`(`id`) ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY(`원자재_id`) REFERENCES `원자재`(`id`) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE `직원` (
	`id`	INT(11)  UNSIGNED ZEROFILL PRIMARY KEY AUTO_INCREMENT,
	`제조공장_id`	INT(3)	UNSIGNED ZEROFILL NOT NULL,
	`직책`	VARCHAR(60)	NOT NULL,
	`성`	VARCHAR(35)	NOT NULL,
	`이름`	VARCHAR(35)	NOT NULL,
	`생년월일`	DATE	NOT NULL,
	`집주소`	VARCHAR(255)	NOT NULL,
	`월급`	INT	NOT NULL DEFAULT 0 CHECK (`월급`>=0),
	FOREIGN KEY(`제조공장_id`) REFERENCES `제조공장`(`id`) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE `구매로그` (
	`id`	INT(11)	UNSIGNED ZEROFILL PRIMARY KEY AUTO_INCREMENT,
	`내용`	TEXT	NOT NULL,
	`제조공장_id`	INT(3)	UNSIGNED ZEROFILL NOT NULL,
	`상태`	TINYINT	UNSIGNED NOT NULL DEFAULT 1 CHECK(`상태` >= 1 AND `상태` <= 3),
	`금액`	BIGINT	NOT NULL,
	`일자`	TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	FOREIGN KEY(`제조공장_id`) REFERENCES `제조공장`(`id`) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE `원자재구매` (
	`id`	INT(11)	UNSIGNED ZEROFILL PRIMARY KEY,
	`원자재거래처_id`	INT(3)	UNSIGNED ZEROFILL NOT NULL,
	`원자재_id`	INT(11)	UNSIGNED ZEROFILL NOT NULL,
	`구매량`	INT	NOT NULL CHECK (`구매량` >= 0),
	FOREIGN KEY(`id`) REFERENCES `구매로그`(`id`) ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY(`원자재거래처_id`) REFERENCES `원자재거래처`(`id`) ON UPDATE CASCADE,
	FOREIGN KEY(`원자재_id`) REFERENCES `원자재`(`id`) ON UPDATE CASCADE
);

CREATE TABLE `주문` (
	`id`	INT(11)	UNSIGNED ZEROFILL PRIMARY KEY AUTO_INCREMENT,
	`고객_id`	INT(11)	UNSIGNED ZEROFILL NOT NULL,
	`택배업체_id`	INT(3)	UNSIGNED ZEROFILL NOT NULL,
	`제조공장_id`	INT(3)	UNSIGNED ZEROFILL NULL	DEFAULT NULL,
	`결제금액`	INT	NOT NULL DEFAULT 0 CHECK (`결제금액`>=0),
	`주소`	VARCHAR(255)	NOT NULL,
	`우편번호`	VARCHAR(10) NOT NULL,
	`상태`	TINYINT UNSIGNED NOT NULL DEFAULT 1 CHECK (`상태`>=1 AND `상태`<=6),
	`주문일자`	TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	`제조일자`	TIMESTAMP DEFAULT NULL,
	`배송일자`	TIMESTAMP DEFAULT NULL,
	`배송완료일자`	TIMESTAMP DEFAULT NULL,
	FOREIGN KEY(`고객_id`) REFERENCES `고객`(`id`) ON UPDATE CASCADE,
	FOREIGN KEY(`택배업체_id`) REFERENCES `택배업체`(`id`) ON UPDATE CASCADE,
	FOREIGN KEY(`제조공장_id`) REFERENCES `제조공장`(`id`) ON UPDATE CASCADE
);

CREATE TABLE `주문제품` (
	`주문_id`	INT(11)	UNSIGNED ZEROFILL NOT NULL,
	`제품_id`	INT(11)	UNSIGNED ZEROFILL NOT NULL,
	`수량`	INT	NOT NULL CHECK (`수량` >= 0 ),
	FOREIGN KEY(`주문_id`) REFERENCES `주문`(`id`) ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY(`제품_id`) REFERENCES `제품`(`id`) ON UPDATE CASCADE 
);

DELIMITER $$
CREATE TRIGGER update_quantity_by_order
AFTER UPDATE ON `주문`
FOR EACH ROW
BEGIN
	IF OLD.`상태` = NEW.`상태`+1 THEN
		-- 제조 접수 중 >> 제조 중
		IF OLD.`상태`=1 AND NEW.`상태`=2 THEN
			UPDATE `원자재보관현황`
				INNER JOIN (
					SELECT `제품별필요원자재`.`원자재_id` AS id, SUM(`주문제품`.`수량`*`제품별필요원자재`.`필요량`) AS quantity
					FROM `제품별필요원자재` 
						INNER JOIN `주문제품` ON `제품별필요원자재`.`제품_id`=`주문제품`.`제품_id`
					WHERE `주문제품`.`주문_id`=NEW.`id`
					GROUP BY `제품별필요원자재`.`원자재_id`
				) AS total_table
			SET `원자재보관현황`.`필요량`=`원자재보관현황`.`필요량`+total_table.quantity
			WHERE `원자재보관현황`.`id` = total_table.id;

		-- 제조 중 >> 배송 준비 중
		ELSEIF OLD.`상태`=2 AND NEW.`상태`=3 THEN
			UPDATE `주문` SET `제조일자`=CURRENT_TIMESTAMP WHERE `id`=NEW.`id`;
			UPDATE `원자재보관현황`
				INNER JOIN (
					SELECT `제품별필요원자재`.`원자재_id` AS id, SUM(`주문제품`.`수량`*`제품별필요원자재`.`필요량`) AS quantity
					FROM `제품별필요원자재` 
						INNER JOIN `주문제품` ON `제품별필요원자재`.`제품_id`=`주문제품`.`제품_id`
					WHERE `주문제품`.`주문_id`=NEW.`id` 
					GROUP BY `제품별필요원자재`.`원자재_id`
				) AS total_table
			SET `원자재보관현황`.`필요량`=`원자재보관현황`.`필요량`-total_table.quantity,
				`원자재보관현황`.`보관량`=`원자재보관현황`.`보관량`-total_table.quantity
			WHERE `원자재보관현황`.`id`=total_table.id;

		-- 배송 준비 중 >> 배송 중
		ELSEIF OLD.`상태`=3 AND NEW.`상태`=4 THEN
			UPDATE `주문` SET `배송일자`=CURRENT_TIMESTAMP WHERE `id`=NEW.`id`;
		
		-- 배송 중 >> 배송 완료
		ELSEIF OLD.`상태`=4 AND NEW.`상태`=5 THEN
			UPDATE `주문` SET `배송완료일자`=CURRENT_TIMESTAMP WHERE `id`=NEW.`id`;
		END IF;
	END IF;
END $$

DELIMITER $$
CREATE TRIGGER update_quantity_by_order_materials
	AFTER INSERT ON `원자재구매`
	FOR EACH ROW
BEGIN
	-- 변수 선언
	DECLARE stat TINYINT;
	
	-- 상태 조회
	SELECT `상태` INTO stat FROM `구매로그` WHERE `id` = NEW.`id`;

	-- 상태가 1이면 보관량 업데이트
	IF stat = 1 THEN
		UPDATE `원자재보관현황`
		SET `보관량` = `보관량` + NEW.`구매량`
		WHERE `id` = NEW.`원자재_id`;
	END IF;
END $$

DELIMITER $$
CREATE TRIGGER update_quantity_by_purchase_materials
AFTER UPDATE ON `구매로그`
FOR EACH ROW
BEGIN
	IF OLD.`상태` <> NEW.`상태` 
		AND NEW.`상태`=2 
		AND EXISTS (SELECT * FROM `원자재구매` WHERE `id`=NEW.`id`) THEN
		UPDATE `원자재보관현황` 
			INNER JOIN (
				SELECT `원자재_id`, SUM(`구매량`) AS `총구매량`
				FROM `원자재구매`
				WHERE `id` = NEW.`id`
				GROUP BY `원자재_id`
			) AS `총합`
		ON `원자재보관현황`.`id` = `총합`.`원자재_id`
		SET `원자재보관현황`.`보관량` = `원자재보관현황`.`보관량` + `총합`.`총구매량`;
	END IF;
END $$

DELIMITER $$
CREATE PROCEDURE `ORDER` (
	IN _customer_id INT,
	IN _parcel_id INT,
	IN _home_address VARCHAR(255),
	IN _postal_code VARCHAR(10),
	IN _products JSON
)
PROC_BODY: BEGIN 
	DECLARE _pay INT DEFAULT 0;
	DECLARE i INT DEFAULT 0;
	DECLARE _id INT;
	DECLARE _products_keys TEXT;
	DECLARE _product_key_i_varchar VARCHAR(11);
	DECLARE _product_key_i INT;
	DECLARE _product_quantity_i INT;
	DECLARE price_temp INT;

	IF NOT EXISTS(SELECT `id` FROM `고객` WHERE `id`=_customer_id)
		OR NOT EXISTS(SELECT `id` FROM `택배업체` WHERE `id`=_parcel_id) THEN
		LEAVE PROC_BODY;
	END IF;
	

	START TRANSACTION;
	INSERT INTO `주문`(`고객_id`, `택배업체_id`, `주소`, `우편번호`)
		VALUES (_customer_id, _parcel_id, _home_address, _postal_code);
	
	SET _id=LAST_INSERT_ID();

	SET _products_keys = JSON_UNQUOTE(JSON_KEYS(_products));

	WHILE i < JSON_LENGTH(_products) DO
		SET _product_key_i_varchar = JSON_UNQUOTE(JSON_EXTRACT(_products_keys, CONCAT('$[', i, ']')));
		SET _product_key_i = CAST(_product_key_i_varchar AS SIGNED);
		SET _product_quantity_i = CAST(JSON_UNQUOTE(JSON_EXTRACT(_products, _product_key_i)) AS SIGNED);
		INSERT INTO `주문제품`(`주문_id`, `제품_id`, `수량`) 
			VALUES (_id, _product_key_i, _product_quantity_i);

		SELECT (_product_quantity_i*`정가`) INTO price_temp
			FROM `제품`
			WHERE `id`=_product_key_i;
		SET _pay = _pay + price_temp;
		SET i = i+1;
	END WHILE;
	UPDATE `주문` SET `결제금액`=_pay WHERE `id`=_id;
	COMMIT;
END $$

 