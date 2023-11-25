CREATE TABLE `고객` (
	`id`	INT(11)	UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	`기업명`	VARCHAR(60)	UNIQUE NOT NULL,
	`사업자등록번호`	VARCHAR(10) UNIQUE NOT NULL,
	`전화번호`	VARCHAR(20)	NOT NULL,
	`email`	VARCHAR(320)	NOT NULL,
	`주소`	VARCHAR(255)	NOT NULL,
	`FAX`	VARCHAR(50)
);

CREATE TABLE `제품` (
	`id`	INT(11)	UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	`제품명`	VARCHAR(60)	NOT NULL,
	`정가`	INT	NOT NULL CHECK (`정가`>=0)
);

CREATE TABLE `제조공장` (
	`id`	INT(3) UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	`공장명`	VARCHAR(60)	NOT NULL,
	`주소`	VARCHAR(255)	NOT NULL,
	`연락처`	VARCHAR(20)	NOT NULL
);

CREATE TABLE `원자재` (
	`id`	INT(11)	UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	`구분`	TINYINT	UNSIGNED NOT NULL CHECK (`구분` IN (1,2)),
	`원자재명`	VARCHAR(60)	NOT NULL
);

CREATE TABLE `원자재거래처` (
	`id`	INT(3)	UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	`거래처명`	VARCHAR(60)	NOT NULL,
	`주소`	VARCHAR(255)	NOT NULL,
	`전화번호`	VARCHAR(20)	NOT NULL
);

CREATE TABLE `원자재보관량` (
	`id`	INT(11)	UNSIGNED NOT NULL,
	`제조공장_id` INT(3) UNSIGNED NOT NULL,
	`필요량` INT NOT NULL DEFAULT 0 CHECK(`필요량`>=0),
	`보관량`	INT NOT NULL DEFAULT 0 CHECK(`필요량`>=0),
	FOREIGN KEY (`id`) REFERENCES `원자재`(`id`) ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY (`제조공장_id`) REFERENCES `제조공장`(`id`) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE `택배업체거래처` (
	`id`	INT(3)	UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	`거래처명`	VARCHAR(60)	UNIQUE NOT NULL,
	`연락처`	VARCHAR(20)	NOT NULL,
	`택배비용`	INT	NOT NULL
);

CREATE TABLE `제품별필요원자재` (
	`제품_id`	INT(11)	UNSIGNED NOT NULL,
	`원자재_id`	INT(11)	UNSIGNED NOT NULL,
	`필요량`	INT	NOT NULL CHECK (`필요량`>=0),
	FOREIGN KEY(`제품_id`) REFERENCES `제품`(`id`) ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY(`원자재_id`) REFERENCES `원자재`(`id`) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE `직원` (
	`id`	INT(11)  UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	`제조공장_id`	INT(3)	UNSIGNED NOT NULL,
	`직책`	VARCHAR(60)	NOT NULL,
	`성`	VARCHAR(35)	NOT NULL,
	`이름`	VARCHAR(35)	NOT NULL,
	`생년월일`	DATE	NOT NULL,
	`집주소`	VARCHAR(255)	NOT NULL,
	`월급`	INT	NOT NULL DEFAULT 0 CHECK (`월급`>=0),
	FOREIGN KEY(`제조공장_id`) REFERENCES `제조공장`(`id`) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE `구매로그` (
	`id`	INT(20)	UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	`내용`	VARCHAR(255)	NOT NULL,
	`제조공장_id`	INT(3)	UNSIGNED NOT NULL,
	`상태`	TINYINT	UNSIGNED NOT NULL DEFAULT 1 CHECK(`상태` IN(1,2,3)),
	`금액`	INT	NOT NULL CHECK(`금액` >= 0),
	`구매일자`	TIMESTAMP	NOT NULL,
	FOREIGN KEY(`제조공장_id`) REFERENCES `제조공장`(`id`) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE `원자재구매` (
	`id`	INT(20)	UNSIGNED PRIMARY KEY,
	`원자재거래처_id`	INT(3)	UNSIGNED NOT NULL,
	`원자재_id`	INT(11)	UNSIGNED NOT NULL,
	`구매량`	INT	NOT NULL CHECK (`구매량` >= 0),
	FOREIGN KEY(`id`) REFERENCES `구매로그`(`id`) ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY(`원자재거래처_id`) REFERENCES `원자재거래처`(`id`) ON UPDATE CASCADE,
	FOREIGN KEY(`원자재_id`) REFERENCES `원자재`(`id`) ON UPDATE CASCADE,
);

CREATE TABLE `주문` (
	`id`	INT(11)	UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	`고객_id`	INT(11)	UNSIGNED NOT NULL,
	`택배업체거래처_id`	INT(3)	UNSIGNED NOT NULL,
	`제조공장_id`	INT(3)	UNSIGNED NULL	DEFAULT NULL,
	`결제금액`	INT	NOT NULL CHECK (`결제금액`>=0),
	`주소`	VARCHAR(255)	NOT NULL,
	`우편번호`	INT(10)	UNSIGNED NOT NULL,
	`상태`	TINYINT UNSIGNED NOT NULL DEFAULT 1 CHECK (`상태` IN (1,2,3,4,5,6)),
	`주문일자`	TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	`제조일자`	TIMESTAMP DEFAULT NULL,
	`배송일자`	TIMESTAMP DEFAULT NULL,
	`배송완료일자`	TIMESTAMP DEFAULT NULL,
	FOREIGN KEY(`고객_id`) REFERENCES `고객`(`id`) ON UPDATE CASCADE,
	FOREIGN KEY(`택배업체거래처_id`) REFERENCES `택배업체거래처`(`id`) ON UPDATE CASCADE,
	FOREIGN KEY(`제조공장_id`) REFERENCES `제조공장`(`id`) ON UPDATE CASCADE
);

CREATE TABLE `주문제품` (
	`주문_id`	INT(11)	UNSIGNED NOT NULL,
	`제품_id`	INT(11)	UNSIGNED NOT NULL,
	`수량`	INT	NOT NULL CHECK (`수량` >= 0 ),
	FOREIGN KEY(`주문_id`) REFERENCES `주문`(`id`) ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY(`제품_id`) REFERENCES `제품`(`id`) ON UPDATE CASCADE 
);

DELIMITER $$
CREATE TRIGGER update_quantity_by_status
BEFORE UPDATE ON `주문`
FOR EACH ROW
BEGIN
	IF OLD.`상태` < NEW.`상태` THEN
		-- 제조 접수 중 >> 제조 중
		IF OLD.`상태`=1 AND NEW.`상태`=2 THEN
			UPDATE `원자재보관량`
				INNER JOIN (
					SELECT `제품별필요원자재`.`원자재_id` AS id, SUM(`주문제품`.`수량`*`제품별필요원자재`.`필요량`) AS quantity
					FROM `제품별필요원자재` 
						INNER JOIN `주문제품` ON `제품별필요원자재`.`제품_id`=`주문제품`.`제품_id`
					WHERE `주문제품`.`주문_id`=NEW.`id`
					GROUP BY `제품별필요원자재`.`원자재_id`
				) AS total_table
			SET `원자재보관량`.`필요량`=`원자재보관량`.`필요량`+total_table.quantity
			WHERE `원자재보관량`.`id` = total_table.id;
		END IF;

		-- 제조 중 >> 배송 준비 중
		ELSEIF OLD.`상태`=2 AND NEW.`상태`=3 THEN
			UPDATE `주문` SET `제조일자`=CURRENT_TIMESTAMP WHERE `id`=NEW.`id`;
			UPDATE `원자재보관량`
				INNER JOIN (
					SELECT `제품별필요원자재`.`원자재_id` AS id, SUM(`주문제품`.`수량`*`제품별필요원자재`.`필요량`) AS quantity
					FROM `제품별필요원자재` 
						INNER JOIN `주문제품` ON `제품별필요원자재`.`제품_id`=`주문제품`.`제품_id`
					WHERE `주문제품`.`주문_id`=NEW.`id`
					GROUP BY `제품별필요원자재`.`원자재_id`
				) AS total_table
			SET `원자재보관량`.`필요량`=`원자재보관량`.`필요량`-total_table.quantity,
				`원자재보관량`.`보관량`=`원자재보관량`.`보관량`-total_table.quantity
			WHERE `원자재보관량`.`id`=total_table.id;
		END IF;
		-- 배송 준비 중 >> 배송 중
		ELSEIF OLD.`상태`=3 AND NEW.`상태`=4 THEN
			UPDATE `주문` SET `배송일자`=CURRENT_TIMESTAMP WHERE `id`=NEW.`id`;
		END IF;
		
		-- 배송 중 >> 배송 완료
		ELSEIF OLD.`상태`=4 AND NEW.`상태`=5 THEN
			UPDATE `주문` SET `배송완료일자`=CURRENT_TIMESTAMP WHERE `id`=NEW.`id`;
		END IF;
	END IF;
END $$
DELIMITER;

DELIMITER $$
CREATE TRIGGER update_quantity_by_purchase
AFTER UPDATE ON `구매로그`
FOR EACH ROW
BEGIN
	IF OLD.`상태` <> NEW.`상태` AND NEW.`상태` THEN
		
	END IF;
END $$
DELIMITER;

