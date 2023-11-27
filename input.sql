INSERT INTO `고객`(`기업명`, `사업자등록번호`, `전화번호`, `email`, `주소`, `FAX`) 
VALUES ("한강마트", "1230115379", "0215881588", "gogi@chicken.com", "서울 송파구 거마로 10, 203호", "FAX=279-167-1673@chicken.com");

INSERT INTO `제품`(`제품명`, `정가`)
VALUES ("치킨마요덮밥", 4600);

INSERT INTO `제조공장`(`공장명`, `주소`, `연락처`) 
VALUES ("치킨땡긴다서산분점", "충청남도 서산시 한서1로 14", "02-7984-5614");

INSERT INTO `택배업체`(`업체명`, `연락처`, `택배비용`) 
    VALUES ("로젠택배", "024919479", 10000);

-- add_material_info(manufactures_id, material_name, group, origin)
CALL add_material_info(JSON_ARRAY(1), "계란", 1, "국내산");
CALL add_material_info(JSON_ARRAY(1), "양파", 1, "국내산");
CALL add_material_info(JSON_ARRAY(1), "양배추", 1, "국내산");
CALL add_material_info(JSON_ARRAY(1), "닭가슴살", 1, "국내산");
CALL add_material_info(JSON_ARRAY(1), "마늘", 1, "국내산");
CALL add_material_info(JSON_ARRAY(1), "밀가루", 2, "중국산");
CALL add_material_info(JSON_ARRAY(1), "고춧가루", 2, "중국산");
CALL add_material_info(JSON_ARRAY(1), "설탕", 2, "국내산");
CALL add_material_info(JSON_ARRAY(1), "맛소금", 2, "국내산");
CALL add_material_info(JSON_ARRAY(1), "올리고당", 2, "국내산");
CALL add_material_info(JSON_ARRAY(1), "진간장", 2, "국내산");
CALL add_material_info(JSON_ARRAY(1), "국간장", 2, "국내산");
CALL add_material_info(JSON_ARRAY(1), "마요네즈", 2, "중국산");
CALL add_material_info(JSON_ARRAY(1), "케첩", 2, "중국산");
CALL add_material_info(JSON_ARRAY(1), "맛술", 2, "국내산");
CALL add_material_info(JSON_ARRAY(1), "큰플라스틱그릇", 3, NULL);
CALL add_material_info(JSON_ARRAY(1), "소스포장재", 3, NULL);

CALL insert_product_info("치킨마요덮밥", 4600, JSON_OBJECT(
    '1', 2,
    '2', 1,
    '3', 1,
    '4', 1,
    '10', 1,
    '12', 1,
    '13', 1,
    '16', 1,
    '17', 4
));

INSERT INTO `원자재거래처`(`거래처명`, `주소`, `전화번호`)
VALUES ("한서농협", "충청남도 공주시 신풍면 선학리 210-4", "025648746");

-- order_materials(manufacture_id, vendor_id, _pay, _materials)
CALL order_materials(1, 1, 12345600, JSON_OBJECT(
    '1', 200,
    '2', 100,
    '3', 100,
    '4', 100,
    '10', 100,
    '12', 100,
    '13', 100,
    '16', 100,
    '17', 400
));

-- 원자재 배송 완료
UPDATE `구매로그` SET `상태`=2 WHERE `id`=1;

-- order(customer_id, parcel_id, home_addr, postal_code, products)
CALL order(1, 1, "서울 송파구 오금동 오금로 4가길 7", 05747, JSON_OBJECT('1', 100));

