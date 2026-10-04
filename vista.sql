--inserts necesarios :
-- 1. Insertar Municipalities (sin dependencias)
INSERT INTO municipalities (town, province, population) 
VALUES ('Ciudad1', 'Provincia1', 10000);

-- 2. Insertar Users (sin dependencias)
INSERT INTO users (user_id, id_card, name, surname1, surname2, birthdate, town, province, address, email, phone, type, ban_up2) 
VALUES ('FSDB152', '12345678901234567', 'Juan', 'Perez', 'Lopez', TO_DATE('1990-01-01','YYYY-MM-DD'),
        'Ciudad1', 'Provincia1', 'Calle Ejemplo 123', 'juan.perez@example.com', 600987654, 'A', NULL);

-- 3. Insertar Books (sin dependencias)
INSERT INTO books (title, author, country, language, pub_date, alt_title, topic, content, awards) 
VALUES ('El Gran Libro', 'Autor Ejemplo', 'España', 'Español', 2020, 'Libro Alternativo',
        'Ciencia', 'Contenido del libro...', 'Premio Ejemplo');

-- 4. Insertar Editions (depende de Books, mediante el isbn)
INSERT INTO editions (isbn, title, author, language, alt_languages, edition, publisher, extension, series, copyright,
                      pub_place, dimensions, phy_features, materials, notes, national_lib_id, url) 
VALUES ('1234567890', 'El Gran Libro', 'Autor Ejemplo', 'Español', 'Inglés', '1ra Edición', 'Editorial Ejemplo',
        'Rústico', 'Serie Ejemplo', '2020', 'Madrid', '20x30', 'Papel', 'Plástico', 'Notas sobre el libro...',
        'LIB001', 'http://ejemplo.com');

-- 5. Insertar Copies (depende de Editions por el isbn)
INSERT INTO copies (signature, isbn, condition, comments, deregistered) 
VALUES ('C001', '1234567890', 'N', 'Nuevo', NULL);

-- 6. Insertar Drivers (sin dependencias)
INSERT INTO drivers (passport, email, fullname, birthdate, phone, address, cont_start, cont_end) 
VALUES ('D12345678', 'driver@example.com', 'Conductor Ejemplo', TO_DATE('1985-05-15','YYYY-MM-DD'),
        600987654, 'Dirección Ejemplo', TO_DATE('2020-01-01','YYYY-MM-DD'), NULL);

-- 7. Insertar Bibuses (sin dependencias)
INSERT INTO bibuses (plate, last_itv, next_itv)
VALUES ('BUS001', TO_DATE('2024-01-01','YYYY-MM-DD'), TO_DATE('2025-01-01','YYYY-MM-DD'));

-- 8. Insertar Routes (sin dependencias)
INSERT INTO routes (route_id)
VALUES ('R001');

-- 9. Insertar Stops (depende de Municipalities y Routes)  
-- Se insertan: town, province, address, route_id y stoptime.
INSERT INTO stops (town, province, address, route_id, stoptime)
VALUES ('Ciudad1', 'Provincia1', 'Calle Stop Ejemplo', 'R001', 1234);

-- 10. Insertar Assign_bus (depende de Bibuses y Routes)
INSERT INTO assign_bus (plate, taskdate, route_id)
VALUES ('BUS001', TO_DATE('2025-04-01','YYYY-MM-DD'), 'R001');

-- 11. Insertar Assign_drv (depende de Drivers; se insertan las columnas passport y taskdate)
INSERT INTO assign_drv (passport, taskdate)
VALUES ('D12345678', TO_DATE('2025-04-01','YYYY-MM-DD'));

-- 12. Insertar Services (depende de Stops, Assign_bus y Assign_drv)  
-- La restricción fk_services_stops verifica que (town, province) exista en stops.
-- Además, (bus, taskdate) debe existir en assign_bus y (passport, taskdate) en assign_drv.
INSERT INTO services (town, province, bus, taskdate, passport)
VALUES ('Ciudad1', 'Provincia1', 'BUS001', TO_DATE('2025-04-01','YYYY-MM-DD'), 'D12345678');

-- 13. Insertar Loans (depende de Copies y de Services, según la FK definida)
INSERT INTO loans (signature, user_id, stopdate, town, province, type, time, return) 
VALUES ('C001', 'FSDB152', TO_DATE('2025-04-01','YYYY-MM-DD'),
        'Ciudad1', 'Provincia1', 'R', 60, NULL);

-- 14. Insertar More_Authors (depende de Books, mediante (title, author))
-- La clave foránea requiere que (title, main_author) exista en books.
INSERT INTO More_Authors (title, main_author, alt_authors, mentions)
VALUES ('El Gran Libro', 'Autor Ejemplo', 'Autor Adicional', 'Mentions example');

-- 15. Insertar Posts (depende de Loans)
INSERT INTO posts (signature, user_id, stopdate, post_date, text, likes, dislikes) 
VALUES ('C001', 'FSDB152', TO_DATE('2025-04-01','YYYY-MM-DD'),
        TO_DATE('2025-04-02','YYYY-MM-DD'), 'Comentario sobre la reserva', 10, 0);






-- Crear la vista
CREATE OR REPLACE VIEW my_data AS
SELECT * FROM users
WHERE user_id = USER 
;

--2. Vista my_loans (operable)
CREATE OR REPLACE VIEW my_loans AS
SELECT l.signature, l.user_id, l.stopdate, l.type, l.return,
       p.text, p.post_date, p.likes, p.dislikes
FROM loans l
LEFT JOIN posts p 
  ON l.signature = p.signature 
  AND l.user_id = p.user_id 
  AND l.stopdate = p.stopdate
WHERE l.user_id = USER;


       --Trigger para actualizar/insertar posts:
CREATE OR REPLACE TRIGGER trg_my_loans_update INSTEAD OF UPDATE  ON my_loans
FOR EACH ROW
BEGIN
  -- Actualizar texto del post existente
  IF :OLD.text IS NOT NULL THEN
    UPDATE posts 
    SET text = :NEW.text, 
        post_date = SYSDATE 
    WHERE signature = :OLD.signature 
      AND user_id = :OLD.user_id 
      AND stopdate = :OLD.stopdate;
  ELSE
    -- Insertar nuevo post si no existía
    INSERT INTO posts (signature, user_id, stopdate, post_date, text, likes, dislikes)
    VALUES (:OLD.signature, :OLD.user_id, :OLD.stopdate, SYSDATE, :NEW.text, 0, 0);
  END IF;
END;
/

--3. Vista my_reservations (operable)
CREATE OR REPLACE VIEW my_reservations AS
SELECT signature, user_id, stopdate, town, province, type
FROM loans 
WHERE user_id = USER 
  AND type = 'R';

       --Triggers para operaciones:
              --Insertar reserva:

CREATE OR REPLACE TRIGGER trg_my_reservations_insert
INSTEAD OF INSERT ON my_reservations
FOR EACH ROW
DECLARE
  v_isbn VARCHAR2(20);
  v_available_signature CHAR(5);
BEGIN
  -- Obtener ISBN desde Editions usando la firma (asumiendo relación directa)
  SELECT isbn INTO v_isbn FROM copies WHERE signature = :NEW.signature;
  
  -- Verificar disponibilidad usando el paquete existente
  foundicu.insertar_reserva(v_isbn, :NEW.stopdate, :NEW.user_id);
END;
/
              --Eliminar reserva:

CREATE OR REPLACE TRIGGER trg_my_reservations_delete
INSTEAD OF DELETE ON my_reservations
FOR EACH ROW
BEGIN
  DELETE FROM loans 
  WHERE signature = :OLD.signature 
    AND user_id = :OLD.user_id 
    AND stopdate = :OLD.stopdate 
    AND type = 'R';
END;
/

              --Actualizar fecha de reserva:
CREATE OR REPLACE TRIGGER trg_my_reservations_update
INSTEAD OF UPDATE ON my_reservations
FOR EACH ROW
DECLARE
    v_isbn VARCHAR2(20);
BEGIN
    -- 1. Obtener el ISBN de la copia reservada (usando :OLD.signature como PK)
    SELECT isbn INTO v_isbn 
    FROM copies 
    WHERE signature = :OLD.signature;

    -- 2. Eliminar la reserva antigua
    DELETE FROM loans 
    WHERE signature = :OLD.signature 
      AND user_id = :OLD.user_id 
      AND stopdate = :OLD.stopdate 
      AND type = 'R';

    -- 3. Insertar la nueva reserva con la fecha actualizada
    foundicu.insertar_reserva(
        p_isbn        => v_isbn,
        p_fecha       => :NEW.stopdate,
        p_user_id     => :OLD.user_id
    );

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20030, 'No se encontró el ISBN asociado a la copia.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/
