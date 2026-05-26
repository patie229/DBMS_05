PRAGMA foreign_keys = ON;

CREATE TABLE buch (
    isbn              TEXT          PRIMARY KEY,
    titel             TEXT          NOT NULL,
    erscheinungsjahr  INTEGER       NOT NULL,
    verlag            TEXT          NOT NULL,
    tagesgebuehr      NUMERIC(6,2)  NOT NULL CHECK (tagesgebuehr > 0)
);

CREATE TABLE exemplar (
    exemplar_id  INTEGER  PRIMARY KEY,
    isbn         TEXT     NOT NULL,
    standort     TEXT     NOT NULL,
    FOREIGN KEY (isbn) REFERENCES buch(isbn)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE mitglied (
    mitglied_id     INTEGER  PRIMARY KEY,
    nachname        TEXT     NOT NULL,
    vorname         TEXT     NOT NULL,
    geburtsdatum    DATE     NOT NULL,
    email           TEXT     NOT NULL UNIQUE,
    beitritt_datum  DATE     NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE ausleihe (
    ausleihe_id      INTEGER  PRIMARY KEY,
    exemplar_id      INTEGER  NOT NULL,
    mitglied_id      INTEGER  NOT NULL,
    ausleihe_datum   DATE     NOT NULL,
    rueckgabe_datum  DATE,
    FOREIGN KEY (exemplar_id) REFERENCES exemplar(exemplar_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (mitglied_id) REFERENCES mitglied(mitglied_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CHECK (rueckgabe_datum IS NULL OR rueckgabe_datum >= ausleihe_datum)
);
