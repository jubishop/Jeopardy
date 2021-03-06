CREATE TABLE GAME(
  ID INTEGER PRIMARY KEY,
  DATE INT NOT NULL
);
CREATE TABLE FINAL_JEOPARDY(
  GAME_ID INTEGER PRIMARY KEY,
  CATEGORY TEXT NOT NULL,
  CLUE TEXT NOT NULL,
  ANSWER TEXT NOT NULL
);
CREATE TABLE CATEGORY(
  ID INTEGER PRIMARY KEY AUTOINCREMENT,
  GAME_ID INTEGER NOT NULL,
  CATEGORY TEXT NOT NULL,
  ROUND INT NOT NULL
);
CREATE TABLE QUESTION(
  ID INTEGER PRIMARY KEY AUTOINCREMENT,
  GAME_ID INTEGER NOT NULL,
  CATEGORY_ID INTEGER NOT NULL,
  VALUE INT NOT NULL,
  ROUND INT NOT NULL,
  DAILY_DOUBLE INT NOT NULL,
  CLUE TEXT NOT NULL,
  ANSWER TEXT NOT NULL
);