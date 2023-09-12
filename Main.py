import sys
import psycopg2

conn = psycopg2.connect(
   database="Bank System", user='postgres', password='2003gh03f23', host='127.0.0.1', port= '5432'
)
cursor = conn.cursor()

user = ""

def register_menu():
    print("1. Register")
    print("2. Login")
    print("3. Transaction")
    print("4. Update Balances")
    print("5. Check Balance")
    print("6. Quit")

def signup_menu():
    pass

def login_menu():
    pass

def starting_input(choice):
    if choice == "1":
        print("1.Register\n0.Back")
        choice = input("Enter: ")
        register(choice)
    elif choice == "2":
        print("1.Login\n0.Back")
        choice = input("Enter: ")
        login(choice)
    elif choice == "3":
        print("1.Deposite\n2.Withdraw\n3.Transfer\n4.Interest Payment\n0.Back")
        choice = input("Enter: ")
        transaction(choice)
    elif choice == "4":
        update_balances()
    elif choice == "5":
        check_balance()
    else:
        print("Invalid Input")
        return
    
def register(choice):
    if choice == "0":
        return
    elif choice == '1':
        password = input("Password: ")
        first_name = input("First Name: ")
        last_name = input("Last Name: ")
        national_id = input("National ID: ")
        birthdate = input("Date of Birth (YYYY/MM/DD): ")
        typ = input("Type (client or employee): ")
        interest_rate = input("Interest Rate: ")
        
        cursor.execute("CALL register( %s, %s, %s, %s, %s, %s, %s);", 
                       (password, first_name, last_name, national_id,
                        birthdate, typ, interest_rate))
        print(''.join(conn.notices))
        conn.commit()
        return

def login(choice):
    if choice == "0":
        return
    elif choice == "1":
        username = input("Username: ")
        password = input("Password: ")
        cursor.execute("CALL login(%s, %s);", (username, password))
        print(''.join(conn.notices))
        conn.commit()
        return
    
def transaction(choice):
    if choice == "0":
        return
    elif choice == "1":
        deposite()
        return
    elif choice == "2":
        withdraw()
        return
    elif choice == "3":
        transfer()
        return
    elif choice == "4":
        interest_payment()
        return

def deposite():
    amount = input("Amount: ")
    cursor.execute("CALL deposite(%s);", (amount,))
    print(''.join(conn.notices))
    conn.commit()
    return

def withdraw():
    amount = input("Amount DECIMAL(13,3): ")
    cursor.execute("CALL withdraw(%s);", (amount,))
    print(''.join(conn.notices))
    conn.commit()
    return

def transfer():
    account_number2 = input("Destination Account Number: ")
    amount = input("Amount DECIMAL(13,3): ")
    cursor.execute("CALL transfer(%s, %s);", ( account_number2, amount))
    print(''.join(conn.notices))
    conn.commit()
    return

def interest_payment():
    cursor.execute("CALL interest_payment();")
    print(''.join(conn.notices))
    conn.commit()
    return

def update_balances():
    cursor.execute("CALL update_balances();")
    print(''.join(conn.notices))
    conn.commit()
    return

def check_balance():
    cursor.execute("CALL check_balance();")
    print(''.join(conn.notices))
    conn.commit()
    return

register_menu()
choice = input()
while choice != "6":
    starting_input(choice)
    register_menu()
    choice = input()

if choice == "6":
    print("Have a Good Time!")
    sys.exit("")

conn.commit()
cursor.close()
conn.close()