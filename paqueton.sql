CREATE OR REPLACE PACKAGE BODY foundicu AS
    c_limite_prestamos CONSTANT NUMBER := 5;
 
    PROCEDURE insertar_prestamo(p_signature Loans.signature%TYPE,p_user_id Users.user_id%TYPE
    ) IS
        v_existe_usuario NUMBER;v_reserva_existente NUMBER;v_ban_date Users.ban_up2%TYPE;
        v_copia_status Copies.condition%TYPE;v_disponible NUMBER;
        v_prestamos_activos NUMBER;
    BEGIN
        -- verifica existencia del usuario
        SELECT COUNT(*) INTO v_existe_usuario FROM USERS WHERE USER_ID = p_user_id;
         
        IF v_existe_usuario = 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'usuario no existe.');
        END IF;
        -- verificacamos reserva vigente
        SELECT COUNT(*) INTO v_reserva_existente FROM LOANS -- Corrección aquí
         WHERE SIGNATURE = p_signature
           AND USER_ID = p_user_id
           AND TYPE = 'R'
           AND STOPDATE <= SYSDATE;
 
        IF v_reserva_existente > 0 THEN
            --convertir reserva a préstamo
            UPDATE LOANS
               SET TYPE = 'L',
                   TIME = 20160,
                   RETURN = SYSDATE + 14
             WHERE SIGNATURE = p_signature
               AND USER_ID = p_user_id
               AND TYPE = 'R';
            COMMIT;
            DBMS_OUTPUT.PUT_LINE('reserva convertida en préstamo.');
        ELSE
            -- Validar copia y usuario
            BEGIN
                SELECT CONDITION INTO v_copia_status FROM COPIES WHERE SIGNATURE = p_signature;
                 
                IF v_copia_status = 'D' THEN 
                    RAISE_APPLICATION_ERROR(-20002, 'copia deteriorada.'); 
                END IF;
                
                -- Verificar disponibilidad
                SELECT COUNT(*) INTO v_disponible FROM LOANS
                 WHERE SIGNATURE = p_signature AND RETURN IS NULL;
 
                IF v_disponible > 0 THEN 
                    RAISE_APPLICATION_ERROR(-20003, 'copia no disponible.'); 
                END IF;
                -- Verificar sanción
                SELECT BAN_UP2 INTO v_ban_date FROM USERS WHERE USER_ID = p_user_id;
                 
                IF v_ban_date >= SYSDATE THEN 
                    RAISE_APPLICATION_ERROR(-20004, 'usuario sancionado.'); 
                END IF;
 
                --verificar límite de préstamos
                SELECT COUNT(*) INTO v_prestamos_activos FROM LOANS
                WHERE USER_ID = p_user_id AND (RETURN IS NULL OR TYPE = 'R');
 
                IF v_prestamos_activos >= c_limite_prestamos THEN
                    RAISE_APPLICATION_ERROR(-20005, 'limite alcanzado.');
                END IF;
 
                --insertar prestamo
                INSERT INTO LOANS (
                    SIGNATURE, USER_ID, STOPDATE, TOWN, PROVINCE, TYPE, TIME, RETURN) 
                    VALUES (p_signature, p_user_id, SYSDATE,
                    (SELECT TOWN FROM USERS WHERE USER_ID = p_user_id),
                    (SELECT PROVINCE FROM USERS WHERE USER_ID = p_user_id),'L', 20160, SYSDATE + 14);
                COMMIT;
                
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    RAISE_APPLICATION_ERROR(-20006, 'copia no encontrada.');
            END;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN 
            ROLLBACK;
            RAISE;
    END insertar_prestamo;
 
    PROCEDURE insertar_reserva(p_isbn Editions.isbn%TYPE,p_fecha DATE,p_user_id Users.user_id%TYPE) 
      IS
        v_existe_usuario NUMBER;
        v_existe_isbn NUMBER;
        v_ban_date Users.ban_up2%TYPE;
        v_prestamos_activos NUMBER;
        v_copia_disponible COPIES.signature%TYPE;
    BEGIN
        -- verificar usuario
        SELECT COUNT(*) INTO v_existe_usuario FROM USERS WHERE USER_ID = p_user_id;
         
        IF v_existe_usuario = 0 THEN
            RAISE_APPLICATION_ERROR(-20011, 'usuario no existe.');
        END IF;
 
        -- verificar sancion
        SELECT BAN_UP2 INTO v_ban_date FROM USERS WHERE USER_ID = p_user_id;
         
        IF v_ban_date >= SYSDATE THEN
            RAISE_APPLICATION_ERROR(-20012, 'usuario sancionado.');
        END IF;
 
        -- verificar limite de prestamos/reservas
        SELECT COUNT(*) INTO v_prestamos_activos FROM LOANS WHERE USER_ID = p_user_id AND (RETURN IS NULL OR TYPE = 'R'); 
 
        IF v_prestamos_activos >= c_limite_prestamos THEN
            RAISE_APPLICATION_ERROR(-20013, 'Límite de reservas/préstamos alcanzado.');
        END IF;
 
        -- verificar isbn
        SELECT COUNT(*) INTO v_existe_isbn FROM EDITIONS WHERE ISBN = p_isbn;
         
        IF v_existe_isbn = 0 THEN
            RAISE_APPLICATION_ERROR(-20014, 'ISBN no existe.');
        END IF;
 
        -- buscar copia disponible
        BEGIN
            SELECT SIGNATURE INTO v_copia_disponible
              FROM (
                    SELECT C.SIGNATURE FROM COPIES C
                     WHERE C.ISBN = p_isbn
                       AND C.CONDITION != 'D'
                       AND NVL(C.DEREGISTERED, 'N') = 'N'
                       AND NOT EXISTS (
                           SELECT 1 FROM LOANS L
                            WHERE L.SIGNATURE = C.SIGNATURE
                              AND (
                                  (L.TYPE = 'L' AND L.RETURN IS NULL)
                                  OR 
                                  (L.TYPE = 'R' AND L.STOPDATE BETWEEN p_fecha - 14 AND p_fecha + 14)
                              )
                       )
                     ORDER BY C.SIGNATURE
                   )
             WHERE ROWNUM = 1;
 
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20015, 'no hay copias disponibles para reservar.');
        END;
 
        --insertar reserva
        INSERT INTO LOANS (SIGNATURE, USER_ID, STOPDATE, TOWN, PROVINCE, TYPE, TIME, RETURN) 
        VALUES (
            v_copia_disponible,
            p_user_id,
            p_fecha,
            (SELECT TOWN FROM USERS WHERE USER_ID = p_user_id),
            (SELECT PROVINCE FROM USERS WHERE USER_ID = p_user_id),
            'R',
            0,
            NULL
        );
        COMMIT;
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END insertar_reserva;
 
PROCEDURE registrar_devolucion(p_signature LOANS.signature%TYPE)
IS v_prestamo_activo NUMBER;
  v_copia_existe   NUMBER;
  v_user_id        Users.user_id%TYPE;  --cambia a variable
BEGIN
    -- verificar que la copia está registrada
    SELECT COUNT(*) INTO v_copia_existe FROM COPIES WHERE SIGNATURE = p_signature;
     
    IF v_copia_existe = 0 THEN
        RAISE_APPLICATION_ERROR(-20022, 'copia no registrada.');
    END IF;

    --obtener user_id del prestamo activo para la copia
    SELECT USER_ID INTO v_user_id FROM LOANS WHERE SIGNATURE = p_signature
       AND TYPE = 'L'
       AND RETURN IS NULL
       AND ROWNUM = 1;  --Asume solo un prestamo activo por copia

    --verificar existencia del usuario asociado al prestamo
    SELECT COUNT(*) INTO v_prestamo_activo FROM USERS WHERE USER_ID = v_user_id;

    IF v_prestamo_activo = 0 THEN
        RAISE_APPLICATION_ERROR(-20021, 'usuario no existe.');
    END IF;

    --registrar devolucion
    UPDATE LOANS SET RETURN = SYSDATE
     WHERE SIGNATURE = p_signature
       AND USER_ID = v_user_id
       AND TYPE = 'L'
       AND RETURN IS NULL;
    COMMIT;
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20023, 'no hay prestamo activo para esta copia.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END registrar_devolucion;
END foundicu;
/
 

----bateria de pruebas 
SET SERVEROUTPUT ON;
DECLARE
    v_test_user       CHAR(10) := 'TEST_USER';
    v_real_user       CHAR(10) := 'REAL_USER';
    v_test_signature  CHAR(5)  := 'TEST1';
    v_counter         NUMBER;
    v_municipio_count NUMBER;
BEGIN
    --eliminar datos de pruebas anteriores
    DELETE FROM LOANS WHERE USER_ID = v_real_user;
    DELETE FROM COPIES WHERE SIGNATURE IN ('RSV02', 'TEST3');
    DELETE FROM EDITIONS WHERE ISBN IN ('ISBN_TEST2', 'ISBN_TEST3');
    DELETE FROM BOOKS WHERE TITLE IN ('Libro Test2', 'Libro Test3');
    DELETE FROM SERVICES WHERE BUS IN ('BUS456', 'BUS789');
    DELETE FROM assign_bus WHERE PLATE IN ('BUS456', 'BUS789');
    DELETE FROM assign_drv WHERE PASSPORT IN ('PASS456', 'PASS789');
    DELETE FROM drivers WHERE PASSPORT IN ('PASS456', 'PASS789');
    DELETE FROM bibuses WHERE PLATE IN ('BUS456', 'BUS789');
    DELETE FROM stops WHERE ROUTE_ID IN ('R002', 'R003');
    DELETE FROM routes WHERE ROUTE_ID IN ('R002', 'R003');
    DELETE FROM USERS WHERE USER_ID = v_real_user;
    COMMIT;
 
    -- insertar municipio si no existe
    SELECT COUNT(*) INTO v_municipio_count
      FROM municipalities 
     WHERE TOWN = 'Madrid' AND PROVINCE = 'Madrid';
    
    IF v_municipio_count = 0 THEN
        INSERT INTO municipalities (TOWN, PROVINCE, POPULATION) 
        VALUES ('Madrid', 'Madrid', 50000);
        COMMIT;
    END IF;
 
    -- insertar usuario de prueba
    INSERT INTO USERS (
        USER_ID, ID_CARD, NAME, SURNAME1, BIRTHDATE, TOWN, PROVINCE, ADDRESS, PHONE, TYPE
    ) VALUES (
        v_real_user, 'ID123', 'Test', 'User', SYSDATE - (365*25), 'Madrid', 'Madrid', 'Calle Falsa 123', 912345678, 'A'
    );
    COMMIT;
 
    -- Test1 esperamos la salida de usuario no existe
    BEGIN
        foundicu.insertar_prestamo('CUALQUIERA', 'USER_INEX');
        DBMS_OUTPUT.PUT_LINE('[ERROR] Test 1 falló');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20001 THEN
                DBMS_OUTPUT.PUT_LINE('[OK] Test1: usuario no existe');
            ELSE
                DBMS_OUTPUT.PUT_LINE('[ERROR] Test1');
            END IF;
    END;
 
    -- Test2 conversion de reserva a prestamo
    DECLARE
        v_isbn_test2  VARCHAR2(20) := 'ISBN_TEST2';
        v_book_title  VARCHAR2(200) := 'Libro Test2';
        v_author      VARCHAR2(100) := 'Autor Test2';
        v_signature   CHAR(5)  := 'RSV02';
    BEGIN
        INSERT INTO BOOKS (TITLE, AUTHOR, COUNTRY, LANGUAGE, PUB_DATE)
        VALUES (v_book_title, v_author, 'España', 'Spanish', 2023);
        
        INSERT INTO EDITIONS (ISBN, TITLE, AUTHOR, LANGUAGE, NATIONAL_LIB_ID)
        VALUES (v_isbn_test2, v_book_title, v_author, 'Spanish', 'NL_TEST2');
        COMMIT;
 
        INSERT INTO COPIES (SIGNATURE, ISBN, CONDITION) 
        VALUES (v_signature, v_isbn_test2, 'G');
        COMMIT;
 
        -- insertar servicios para la reserva
        INSERT INTO routes (ROUTE_ID) VALUES ('R002');
 
        --se elimina previamente duplicados en stops
        DELETE FROM stops 
         WHERE ROUTE_ID = 'R002'
           AND ADDRESS = 'Puerta del Sol';
 
        INSERT INTO stops (TOWN, PROVINCE, ADDRESS, ROUTE_ID, STOPTIME)
        VALUES ('Madrid', 'Madrid', 'Puerta del Sol', 'R002', 900);
        
        INSERT INTO bibuses (PLATE, LAST_ITV, NEXT_ITV) 
        VALUES ('BUS456', SYSDATE - 180, SYSDATE + 180);
        
        INSERT INTO drivers (PASSPORT, EMAIL, FULLNAME, BIRTHDATE, PHONE, ADDRESS, CONT_START)
        VALUES ('PASS456', 'driver2@test.com', 'Conductor Test 2', SYSDATE - (365*30), 612345679, 'Calle Virtual 789', SYSDATE - 365);
        
        INSERT INTO assign_bus (PLATE, TASKDATE, ROUTE_ID) 
        VALUES ('BUS456', SYSDATE, 'R002');
        
        INSERT INTO assign_drv (PASSPORT, TASKDATE, ROUTE_ID) 
        VALUES ('PASS456', SYSDATE, 'R002');
        
        INSERT INTO SERVICES (TOWN, PROVINCE, BUS, TASKDATE, PASSPORT)
        VALUES ('Madrid', 'Madrid', 'BUS456', SYSDATE, 'PASS456');
        COMMIT;
 
        INSERT INTO LOANS (SIGNATURE, USER_ID, STOPDATE, TOWN, PROVINCE, TYPE, TIME)
        VALUES (v_signature, v_real_user, SYSDATE, 'Madrid', 'Madrid', 'R', 0);
        COMMIT;
 
        --ejecutar prueba se espera que la reserva se convierta en prestamo
        foundicu.insertar_prestamo(v_signature, v_real_user);
        
        --verificar conversion
        SELECT COUNT(*) INTO v_counter 
          FROM LOANS 
         WHERE SIGNATURE = v_signature 
           AND TYPE = 'L'
           AND RETURN IS NOT NULL;
        
        IF v_counter = 1 THEN
            DBMS_OUTPUT.PUT_LINE('[OK] Test2: Reserva convertida');
        ELSE
            DBMS_OUTPUT.PUT_LINE('[ERROR] Test2: Conversión fallida');
        END IF;
        ROLLBACK;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('[ERROR] Test2');
    END;
 
--ttest3 devolucion exitosa
DECLARE
    v_isbn_test3  VARCHAR2(20) := 'ISBN_TEST3';
    v_book_title  VARCHAR2(200) := 'Libro Test3';
    v_author      VARCHAR2(100) := 'Autor Test3';
    v_signature   CHAR(5)  := 'TEST3';
    v_taskdate    DATE := SYSDATE - 7;
    v_counter     NUMBER;
BEGIN
    INSERT INTO BOOKS (TITLE, AUTHOR, COUNTRY, LANGUAGE, PUB_DATE)
    VALUES (v_book_title, v_author, 'España', 'Spanish', 2023);
    
    INSERT INTO EDITIONS (ISBN, TITLE, AUTHOR, LANGUAGE, NATIONAL_LIB_ID)
    VALUES (v_isbn_test3, v_book_title, v_author, 'Spanish', 'NL_TEST3');
    COMMIT;

    INSERT INTO COPIES (SIGNATURE, ISBN, CONDITION) 
    VALUES (v_signature, v_isbn_test3, 'G');
    COMMIT;

    INSERT INTO routes (ROUTE_ID) VALUES ('R003');

    -- evitar duplicados en stops
    DELETE FROM stops 
     WHERE TOWN = 'Leganes' AND PROVINCE = 'Leganes';
    
    INSERT INTO municipalities (TOWN, PROVINCE, POPULATION)
    VALUES ('Leganes', 'Leganes', 3000);
    
    INSERT INTO stops (TOWN, PROVINCE, ADDRESS, ROUTE_ID, STOPTIME)
    VALUES ('Leganes', 'Leganes', 'Gran Vía', 'R003', 1000);

    INSERT INTO bibuses (PLATE, LAST_ITV, NEXT_ITV) 
    VALUES ('BUS789', SYSDATE - 180, SYSDATE + 180);

    INSERT INTO drivers (PASSPORT, EMAIL, FULLNAME, BIRTHDATE, PHONE, ADDRESS, CONT_START)
    VALUES ('PASS789', 'driver3@test.com', 'Conductor Test 3', SYSDATE - (365*30), 612345670, 'Calle Digital 012', SYSDATE - 365);

    INSERT INTO assign_bus (PLATE, TASKDATE, ROUTE_ID) 
    VALUES ('BUS789', v_taskdate, 'R003');

    INSERT INTO assign_drv (PASSPORT, TASKDATE, ROUTE_ID) 
    VALUES ('PASS789', v_taskdate, 'R003');

    INSERT INTO SERVICES (TOWN, PROVINCE, BUS, TASKDATE, PASSPORT)
    VALUES ('Leganes', 'Leganes', 'BUS789', v_taskdate, 'PASS789');
    COMMIT;
--insertar usuario FSDB152 requerido para el prestamo
INSERT INTO users (USER_ID,ID_CARD,NAME,SURNAME1,SURNAME2,BIRTHDATE,TOWN,PROVINCE,ADDRESS,EMAIL,PHONE,TYPE,BAN_UP2) 
    VALUES ('FSDB152','ID1234567890ABC','Nombre','Apellido1','Apellido2',TO_DATE('1990-01-01', 'YYYY-MM-DD'),'Leganes','Leganes','Calle Ficticia 123','usuario_test3@example.com',612345678,'S',NULL);
COMMIT;

    -- crear préstamo utilizando el usuario actual (FSDB152)
    INSERT INTO LOANS (SIGNATURE, USER_ID, STOPDATE, TOWN, PROVINCE, TYPE, TIME)
    VALUES (v_signature, 'FSDB152', v_taskdate, 'Leganes', 'Leganes', 'L', 20160);
    COMMIT;

    -- ejecutar prueba se registra la devolución usando el procedimiento
    foundicu.registrar_devolucion(v_signature);
 -- verificar devolucion: se cuenta que la columna RETURN tenga valor
    SELECT COUNT(*) INTO v_counter 
      FROM LOANS 
     WHERE SIGNATURE = v_signature 
       AND RETURN IS NOT NULL;

    IF v_counter = 1 THEN
        DBMS_OUTPUT.PUT_LINE('[OK] Test3 devolución exitosa');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[ERROR] Test3 devolución fallida');
    END IF;
    ROLLBACK;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('[ERROR] Test3');
END;

--limpieza final

DELETE FROM LOANS 
 WHERE SIGNATURE IN (
       SELECT SIGNATURE 
         FROM COPIES 
        WHERE ISBN IN ('ISBN_TEST2', 'ISBN_TEST3')
 );
DELETE FROM COPIES WHERE ISBN IN ('ISBN_TEST2', 'ISBN_TEST3');
DELETE FROM EDITIONS WHERE ISBN IN ('ISBN_TEST2', 'ISBN_TEST3');
DELETE FROM BOOKS WHERE TITLE IN ('Libro Test2', 'Libro Test3');
DELETE FROM SERVICES WHERE BUS IN ('BUS456', 'BUS789');
DELETE FROM assign_bus WHERE PLATE IN ('BUS456', 'BUS789');
DELETE FROM assign_drv WHERE PASSPORT IN ('PASS456', 'PASS789');
DELETE FROM stops WHERE ROUTE_ID IN ('R002', 'R003');
DELETE FROM routes WHERE ROUTE_ID IN ('R002', 'R003');
DELETE FROM bibuses WHERE PLATE IN ('BUS456', 'BUS789');
DELETE FROM drivers WHERE PASSPORT IN ('PASS456', 'PASS789');
DELETE FROM USERS WHERE USER_ID = v_real_user;
COMMIT;
END;
/
