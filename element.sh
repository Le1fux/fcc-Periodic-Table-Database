#!/bin/bash

PSQL="psql -X --username=freecodecamp --dbname=periodic_table --tuples-only -c"

# Main function to start the script
START_PROGRAM() {
  CHECK=$($PSQL "SELECT COUNT(*) FROM elements WHERE atomic_number=1000;" | tr -d '[:space:]')

  if [[ $CHECK -gt 0 ]]; then
    FIX_DB
    clear
  fi

  MAIN_PROGRAM "$1"
}

# Function to handle input validation
MAIN_PROGRAM() {
  if [[ -z $1 ]]; then
    echo "Please provide an element as an argument."
  else
    PRINT_ELEMENT "$1"
  fi
}

# Function to print element details
PRINT_ELEMENT() {
  INPUT="$1"

  # Determine if input is atomic number, symbol, or name
  if [[ $INPUT =~ ^[0-9]+$ ]]; then
    ATOMIC_NUMBER=$($PSQL "SELECT atomic_number FROM elements WHERE atomic_number=$INPUT;" | tr -d '[:space:]')
  else
    ATOMIC_NUMBER=$($PSQL "SELECT atomic_number FROM elements WHERE symbol='$INPUT' OR name='$INPUT';" | tr -d '[:space:]')
  fi

  # If element is not found
  if [[ -z $ATOMIC_NUMBER ]]; then
    echo "I could not find that element in the database."
  else
    # Fetch element details
    ELEMENT_DETAILS=$($PSQL "
      SELECT e.atomic_number, e.name, e.symbol, t.type, p.atomic_mass, p.melting_point_celsius, p.boiling_point_celsius 
      FROM elements e
      JOIN properties p ON e.atomic_number = p.atomic_number
      JOIN types t ON p.type_id = t.type_id
      WHERE e.atomic_number = $ATOMIC_NUMBER;")

    # Format and print output
    echo "$ELEMENT_DETAILS" | while IFS=" |" read -r AT_NUM NAME SYMBOL TYPE MASS MELTING BOILING; do
      echo "The element with atomic number $AT_NUM is $NAME ($SYMBOL). It's a $TYPE, with a mass of $MASS amu. $NAME has a melting point of $MELTING celsius and a boiling point of $BOILING celsius."
    done
  fi
}

# Function to fix database structure
FIX_DB() {
  echo "Fixing database..."

  # Rename columns
  $PSQL "ALTER TABLE properties RENAME COLUMN weight TO atomic_mass;"
  $PSQL "ALTER TABLE properties RENAME COLUMN melting_point TO melting_point_celsius;"
  $PSQL "ALTER TABLE properties RENAME COLUMN boiling_point TO boiling_point_celsius;"

  # Add constraints
  $PSQL "ALTER TABLE properties ALTER COLUMN melting_point_celsius SET NOT NULL;"
  $PSQL "ALTER TABLE properties ALTER COLUMN boiling_point_celsius SET NOT NULL;"
  $PSQL "ALTER TABLE elements ADD UNIQUE(symbol);"
  $PSQL "ALTER TABLE elements ADD UNIQUE(name);"
  $PSQL "ALTER TABLE elements ALTER COLUMN symbol SET NOT NULL;"
  $PSQL "ALTER TABLE elements ALTER COLUMN name SET NOT NULL;"
  $PSQL "ALTER TABLE properties ADD FOREIGN KEY (atomic_number) REFERENCES elements(atomic_number);"

  # Create and populate types table
  $PSQL "CREATE TABLE IF NOT EXISTS types(type_id SERIAL PRIMARY KEY, type VARCHAR(20) NOT NULL);"
  $PSQL "INSERT INTO types(type) SELECT DISTINCT(type) FROM properties ON CONFLICT DO NOTHING;"

  # Add type_id column and foreign key reference
  $PSQL "ALTER TABLE properties ADD COLUMN IF NOT EXISTS type_id INT;"
  $PSQL "ALTER TABLE properties ADD FOREIGN KEY(type_id) REFERENCES types(type_id);"
  $PSQL "UPDATE properties SET type_id = (SELECT type_id FROM types WHERE properties.type = types.type);"
  $PSQL "ALTER TABLE properties ALTER COLUMN type_id SET NOT NULL;"

  # Format data
  $PSQL "UPDATE elements SET symbol=INITCAP(symbol);"
  $PSQL "ALTER TABLE properties ALTER COLUMN atomic_mass TYPE FLOAT USING atomic_mass::double precision;"

  # Insert missing elements
  $PSQL "INSERT INTO elements(atomic_number, symbol, name) VALUES (9, 'F', 'Fluorine') ON CONFLICT DO NOTHING;"
  $PSQL "INSERT INTO properties(atomic_number, type, melting_point_celsius, boiling_point_celsius, type_id, atomic_mass) VALUES (9, 'nonmetal', -220, -188.1, 3, 18.998) ON CONFLICT DO NOTHING;"

  $PSQL "INSERT INTO elements(atomic_number, symbol, name) VALUES (10, 'Ne', 'Neon') ON CONFLICT DO NOTHING;"
  $PSQL "INSERT INTO properties(atomic_number, type, melting_point_celsius, boiling_point_celsius, type_id, atomic_mass) VALUES (10, 'nonmetal', -248.6, -246.1, 3, 20.18) ON CONFLICT DO NOTHING;"

  # Clean up unnecessary data
  $PSQL "DELETE FROM properties WHERE atomic_number=1000;"
  $PSQL "DELETE FROM elements WHERE atomic_number=1000;"

  # Remove type column
  $PSQL "ALTER TABLE properties DROP COLUMN IF EXISTS type;"
}

# Start the script
START_PROGRAM "$1"
