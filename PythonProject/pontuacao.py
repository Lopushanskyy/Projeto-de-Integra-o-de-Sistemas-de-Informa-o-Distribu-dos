import sys
import pymysql
from mysql.connector import Error
import mysql.connector as mariadb

usermysqliscte = "aluno"
passmysqliscte = "aluno"
hostiscte = "194.210.86.10"
databasemysql = "maze"

try:
    connection = mariadb.connect(host=hostiscte, user=usermysqliscte, passwd=passmysqliscte, db=databasemysql,
                                 connect_timeout=1000, autocommit=True)
    print("Connected to MySQL ISCTE Server Sound")
except Error as e:
    print("Error while connecting to MySQL ISCTE Server Sound", e)
cursor = connection.cursor()

if len(sys.argv) == 2:
    playeNumber = int(sys.argv[1])
    sql = "SELECT `Score`, `attempt`,`Room` FROM `roomsscore` WHERE `Player` =" + str(playeNumber) + ";"
    try:
        cursor.execute(sql)
        records = cursor.fetchall()
        for row in records:
            Score = float(row[0])
            attempt = int(row[0])
            Room = int(row[0])
            print(Score)
            print(attempt)
            print(Room)
    except:
        print("Error: unable to get Score Data", sql)