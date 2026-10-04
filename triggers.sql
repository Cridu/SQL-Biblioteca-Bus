--Trigger num 1
CREATE OR REPLACE TRIGGER trg_prevent_institutional_posts
BEFORE INSERT ON posts
FOR EACH ROW
DECLARE
    tipo_user users.type%TYPE;
BEGIN
    SELECT type INTO tipo_user
    FROM users
    WHERE user_id = :NEW.user_id;

    IF tipo_user = 'L' THEN 
        RAISE_APPLICATION_ERROR(
            -20001,
            'Error: Usuarios institucionales no pueden crear posts.'
        );
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        NULL; 
END;
/



--Trigger num 2
CREATE OR REPLACE TRIGGER trigger_deteriorado
BEFORE UPDATE OF condition ON COPIES
FOR EACH ROW
BEGIN
  IF :NEW.condition = 'DETERIORADO' THEN
    :NEW.deregistered := SYSDATE;
  END IF;
END;
/

--Trigger num 4
ALTER TABLE books ADD lecturas NUMBER DEFAULT 0;

CREATE OR REPLACE TRIGGER trg_loans_lecturas
AFTER INSERT ON loans
FOR EACH ROW
DECLARE
    v_isbn  editions.isbn%TYPE;
    v_title books.title%TYPE;
    v_author books.author%TYPE;
BEGIN
    -- Obtener ISBN de la copia prestada
    SELECT isbn INTO v_isbn FROM copies WHERE signature = :NEW.signature;
    
    -- Obtener título y autor del libro
    SELECT title, author INTO v_title, v_author FROM editions WHERE isbn = v_isbn;
    
    -- Actualizar contador de lecturas
    UPDATE books
    SET lecturas = lecturas + 1
    WHERE title = v_title AND author = v_author;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        NULL;
END;
/