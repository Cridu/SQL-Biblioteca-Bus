-- Trigger 1
SELECT USER_ID, TYPE 
FROM users 
WHERE USER_ID = '9994309605';

-- 2. Insertar con fechas válidas para CK_POSTS_DATES
INSERT INTO posts (SIGNATURE, USER_ID, STOPDATE, POST_DATE, TEXT, LIKES, DISLIKES)
VALUES (
    'TEST1', 
    '9994309605', 
    TO_DATE('2023-10-01', 'YYYY-MM-DD'),  -- STOPDATE (fecha pasada)
    SYSDATE,                              -- POST_DATE (fecha actual)
    'Post de prueba', 
    0, 
    0
);


--Trigger 2
-- Insertar un libro y una copia de ejemplo (si no existen)
INSERT INTO books (title, author, country, language, pub_date) 
VALUES ('El Quijote', 'Cervantes', 'Spain', 'Spanish', 1605);

INSERT INTO editions (isbn, title, author, language, national_lib_id) 
VALUES ('123-456', 'El Quijote', 'Cervantes', 'Spanish', 'LIB-001');

INSERT INTO copies (signature, isbn, condition) 
VALUES ('COPY1', '123-456', 'G');

--Cambio para poner a prueba el trigger (adebe devolver D)
UPDATE copies 
SET condition = 'D' 
WHERE signature = 'COPY1';

--Trigrer 4
-- (Meter el codigo directamente en la terminal para que lo lea bien)
INSERT INTO loans (signature, user_id, stopdate, town, province, type, time, return)
VALUES (
    'OI977', 
    '0010126950', 
    TO_DATE('2024-11-16', 'YYYY-MM-DD'), 
    'Atalaya de Debajo', 
    'Córdoba', 
    'L', 
    0, 
    NULL
);

COMMIT;

--Comprobacion
SELECT lecturas 
FROM books 
WHERE title = 'Monsignor Quixote' AND author = 'Greene, Graham, ( 1904-1991)';