# Student-History-Vault
This is a Data Pipeline with temporal modeling project designed to manage and track student records within a University setting. Capturing how student metrics such as academic averages, attendance, and honors eligibility evolve over multiple semesters.
  The system supports:
    **1. Incremental Updates (for efficient, periodic data ingestion)**
    **2. Batch Reconstructive Views (for generating a complete historical record easily)**


## 📌 Overview

This is a project I will pitch to my University. A robust SQL-based data pipeline designed to manage and track student records. It utilizes temporal modeling to track the changes in the academic performance of students. Containing columns such as **average per academic level, cumulative average, cumulative student history, academic honors, and etc.**

## 🧰 Tech Stack

- **Database:** PostgreSQL (Advanced Types, Arrays, and CTEs)
- **Concepts** Temporal Data Modeling, ETL Staging, SCD (Slowly Changing Dimensions) logic
- **Languages:** SQL

## 🧠 Objectives

I've seen the inefficiencies of my University in calculating academic awards eligebility. So with this data pipeline along with the data from our student portal, I want to:
  1. Save countless hours of the faculties, students, chairpersons, and deans of the university
  2. Have a cleaner Historical data of Student Records for easier tracking.

## ⚙️ Architecture

🛢️ Source Code Reference:
[student-history-vault.sql]()


  Includes:
  - Incremental (Iterative) Update Query
  - Batch (Reconstructive) View
    

## 📊 Raw Data :
[student_performance_raw.csv]()


## ✉️ Contact
For questions, feedback, or collaboration:

**Dylan Cortez**
