
CREATE TRIGGER update_quantity_by_status
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
	END

DELIMITER $$
CREATE TRIGGER update_quantity_by_purchase
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
DELIMITER ;

CREATE TRIGGER update_quantity_by_purchase_complete
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
	END

CREATE PROCEDURE `ORDER` (
		IN _customer_id INT,
		IN _parcel_id INT,
		IN _home_address VARCHAR(255),
		IN _postal_code VARCHAR(10),
		IN _products JSON
	)
	BEGIN
		IF NOT EXISTS(SELECT `id` FROM `고객` WHERE `id`=_customer_id)
		  OR NOT EXISTS(SELECT `id` FROM `택배업체` WHERE `id`=_parcel_id) THEN
			LEAVE;
		END IF;

		DECLARE _pay INT DEFAULT 0;
		DECLARE i INT DEFAULT 0;

		START TRANSACTION;
		INSERT INTO `주문`(`고객_id`, `택배업체_id`, `주소`, `우편번호`)
			VALUES (_customer_id, _parcel_id, _home_address, _postal_code);
		
		DECLARE _id INT DEFAULT LAST_INSERT_ID();

		DECLARE _products_keys TEXT 
			DEFAULT JSON_UNQUOTE(JSON_KEYS(_products));
		DECLARE _product_key_i_varchar VARCHAR(11);
		DECLARE _product_key_i INT;
		DECLARE _product_quantity_i INT;
		DECLARE price_temp INT;

		WHILE i < JSON_LENGTH(_products) DO
			SET _product_key_i_varchar = JSON_UNQUOTE(JSON_EXTRACT(_products_keys, CONCAT('$[', i, ']')));
			SET _product_key_i = CAST(_product_key_i_varchar AS INT);
			SET _product_quantity_i = CAST(JSON_UNQUOTE(JSON_EXTRACT(_products, _product_key_i)) AS INT);
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
	END