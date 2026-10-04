WITH LibrosMultilingues AS (
    SELECT b.title, b.author
    FROM BOOKS b
    JOIN EDITIONS e 
      ON b.title = e.title 
     AND b.author = e.author
    GROUP BY b.title, b.author
    HAVING COUNT(DISTINCT e.language) >= 3
),
LibrosSinPrestamos AS (
    SELECT DISTINCT b.title, b.author
    FROM BOOKS b
    JOIN EDITIONS e 
      ON b.title = e.title 
     AND b.author = e.author
    JOIN COPIES c 
      ON e.isbn = c.isbn
    WHERE NOT EXISTS (
        SELECT 1
        FROM LOANS l
        WHERE l.signature = c.signature
    )
)
SELECT title, author
FROM LibrosMultilingues
INTERSECT
SELECT title, author
FROM LibrosSinPrestamos;

-----------------------------------------------------------------------------------------------------

SELECT 
    d.fullname AS Nombre_Completo,
    TRUNC(MONTHS_BETWEEN(SYSDATE, d.birthdate) / 12) AS Edad,  -- Paréntesis cerrado después de /12
    TRUNC(MONTHS_BETWEEN(NVL(d.cont_end, SYSDATE), d.cont_start) / 12) AS Antiguedad_Contrato,
    COUNT(DISTINCT EXTRACT(YEAR FROM a.taskdate)) AS Anios_Activo,
    COUNT(a.taskdate) / NULLIF(COUNT(DISTINCT EXTRACT(YEAR FROM a.taskdate)), 0) AS Media_Paradas_Anio,
    COUNT(l.signature) / NULLIF(COUNT(DISTINCT EXTRACT(YEAR FROM a.taskdate)), 0) AS Media_Prestamos_Anio,
    (COUNT(CASE WHEN l.return IS NULL THEN 1 END) / NULLIF(COUNT(l.signature), 0)) * 100 AS Porcentaje_Prestamos_No_Devueltos
FROM 
    DRIVERS d
LEFT JOIN 
    ASSIGN_DRV a ON d.passport = a.passport
-- Corrección: Relación lógica ausente. Si se desea vincular conductores con préstamos, debe hacerse a través de Users.
LEFT JOIN 
    USERS u ON u.ID_card = d.passport  -- Asumiendo que Drivers.passport coincide con Users.ID_card
LEFT JOIN 
    LOANS l ON u.user_ID = l.USER_ID  -- Usar USERID en mayúsculas si es necesario
GROUP BY 
    d.passport, d.fullname, d.birthdate, d.cont_start, d.cont_end;
