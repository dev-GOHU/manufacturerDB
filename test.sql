DELIMITER $$
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
	END $$
DELIMITER;