#! /bin/bash

# Define the PSQL command for connecting to the salon database
PSQL="psql --username=freecodecamp --dbname=salon --tuples-only -c"

# Create the customers, services, and appointments tables

echo "Creating customers table..."
$PSQL "CREATE TABLE IF NOT EXISTS customers(
  customer_id SERIAL PRIMARY KEY,
  name VARCHAR,
  phone VARCHAR UNIQUE
);"

echo "Creating services table..."
$PSQL "CREATE TABLE IF NOT EXISTS services(
  service_id SERIAL PRIMARY KEY,
  name VARCHAR NOT NULL
);"

echo "Creating appointments table..."
$PSQL "CREATE TABLE IF NOT EXISTS appointments(
  appointment_id SERIAL PRIMARY KEY,
  customer_id INTEGER REFERENCES customers(customer_id),
  service_id INTEGER REFERENCES services(service_id),
  time VARCHAR
);"

# Insert services if there are less than 3 services
SERVICES_COUNT=$($PSQL "SELECT COUNT(*) FROM services;")
if [[ $SERVICES_COUNT -lt 3 ]]
then
  echo "Inserting default services..."
  # Reset services table to ensure service_id 1 exists as expected
  $PSQL "TRUNCATE services RESTART IDENTITY;"
  $PSQL "INSERT INTO services(name) VALUES('cut'), ('color'), ('perm');"
fi

# MAIN_MENU: Display services and prompt for a valid service selection.
MAIN_MENU() {
  echo -e "\n~~~~~ MY SALON ~~~~~\n"
  echo "Welcome to My Salon, how can I help you?"
  # Get list of services ordered by service_id
  SERVICES_LIST=$($PSQL "SELECT service_id, name FROM services ORDER BY service_id;")
  
  # Display the list in the format: "1) cut"
  echo "$SERVICES_LIST" | while read SERVICE_ID BAR NAME
  do
    if [[ ! -z $SERVICE_ID ]]
    then
      echo "$SERVICE_ID) $NAME"
    fi
  done

  # Read the user's service choice
  read SERVICE_ID_SELECTED

  # Validate the service_id
  SERVICE_NAME=$($PSQL "SELECT name FROM services WHERE service_id='$SERVICE_ID_SELECTED';")
  if [[ -z $SERVICE_NAME ]]
  then
    echo -e "\nI could not find that service. What would you like today?"
    MAIN_MENU
  else
    GET_CUSTOMER_INFO "$SERVICE_ID_SELECTED" "$SERVICE_NAME"
  fi
}

# GET_CUSTOMER_INFO: Prompt for customer phone, insert new customer if necessary, and get service time.
GET_CUSTOMER_INFO() {
  SERVICE_ID_SELECTED=$1
  SERVICE_NAME_FORMATTED=$(echo $2 | sed -r 's/^ *| *$//g')  # Trim whitespace

  echo -e "\nWhat's your phone number?"
  read CUSTOMER_PHONE

  # Look up the customer's name using the phone number
  CUSTOMER_NAME=$($PSQL "SELECT name FROM customers WHERE phone='$CUSTOMER_PHONE';")
  
  if [[ -z $CUSTOMER_NAME ]]
  then
    echo -e "\nI don't have a record for that phone number, what's your name?"
    read CUSTOMER_NAME
    # Insert the new customer into the customers table
    INSERT_CUSTOMER_RESULT=$($PSQL "INSERT INTO customers(name, phone) VALUES('$CUSTOMER_NAME', '$CUSTOMER_PHONE');")
  fi
  
  echo -e "\nWhat time would you like your $SERVICE_NAME_FORMATTED, $CUSTOMER_NAME?"
  read SERVICE_TIME
  
  # Get the customer_id for this phone number
  CUSTOMER_ID=$($PSQL "SELECT customer_id FROM customers WHERE phone='$CUSTOMER_PHONE';")
  
  # Insert the appointment into the appointments table
  INSERT_APPOINTMENT_RESULT=$($PSQL "INSERT INTO appointments(customer_id, service_id, time) VALUES($CUSTOMER_ID, $SERVICE_ID_SELECTED, '$SERVICE_TIME');")
  
  echo -e "\nI have put you down for a $SERVICE_NAME_FORMATTED at $SERVICE_TIME, $CUSTOMER_NAME."
}

# Run the main menu to start the process
MAIN_MENU
