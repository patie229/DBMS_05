PRAGMA foreign_keys = ON;

-- Books
INSERT INTO buch VALUES ('978-3-423-08733-2', 'Steppenwolf',     1927, 'dtv',      0.50);
INSERT INTO buch VALUES ('978-3-518-36893-4', 'Homo Faber',      1957, 'Suhrkamp', 0.50);
INSERT INTO buch VALUES ('978-3-257-20456-6', 'Der Vorleser',    1995, 'Diogenes', 0.75);
INSERT INTO buch VALUES ('978-3-596-18296-4', 'Das Parfum',      1985, 'Fischer',  0.75);
INSERT INTO buch VALUES ('978-3-423-13571-9', 'Die Verwandlung', 1915, 'dtv',      0.30);

-- Copies
INSERT INTO exemplar VALUES (1, '978-3-423-08733-2', 'A-01-3');
INSERT INTO exemplar VALUES (2, '978-3-423-08733-2', 'A-01-4');
INSERT INTO exemplar VALUES (3, '978-3-518-36893-4', 'A-02-1');
INSERT INTO exemplar VALUES (4, '978-3-257-20456-6', 'B-01-7');
INSERT INTO exemplar VALUES (5, '978-3-596-18296-4', 'B-02-2');
INSERT INTO exemplar VALUES (6, '978-3-423-13571-9', 'A-03-1');

-- Members (DEFAULT for beitritt_datum except Klara Sommer)
INSERT INTO mitglied (nachname, vorname, geburtsdatum, email)
VALUES ('Berger',   'Jonas', '2001-04-12', 'jonas.berger@mail.de');

INSERT INTO mitglied (nachname, vorname, geburtsdatum, email, beitritt_datum)
VALUES ('Sommer',   'Klara', '1985-11-30', 'klara.sommer@web.de', '2019-03-15');

INSERT INTO mitglied (nachname, vorname, geburtsdatum, email)
VALUES ('Hartmann', 'Lea',   '1998-07-08', 'lea.hartmann@example.com');

-- Loans
INSERT INTO ausleihe VALUES (1, 1, 1, '2026-05-01', '2026-05-10');
INSERT INTO ausleihe VALUES (2, 3, 2, '2026-05-05', NULL);
INSERT INTO ausleihe VALUES (3, 4, 1, '2026-05-12', NULL);
INSERT INTO ausleihe VALUES (4, 6, 3, '2026-04-20', '2026-04-28');
