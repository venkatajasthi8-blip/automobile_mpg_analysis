# Who Really Built the Most Fuel-Efficient Cars? (1970–1982)

An end-to-end data analysis project using **Python**, **MySQL** and **Tableau** on 398 cars sold between 1970 and 1982.

![Overview dashboard](automobile_project/images/overview_dashboard.png)

---

## The problem

Between 1970 and 1982, two oil crises pushed car makers to cut fuel use fast. Looking only at raw MPG, it's easy to conclude that "Japanese and European cars were the most efficient" and stop there.

But raw MPG is not a fair comparison. A small, light car will always use less fuel than a big, heavy one. Ranking brands by average MPG mostly shows **who built the smallest cars**, not **who built the most efficient cars for their size**.

So this project asks:

> **Once a car's weight and model year are taken into account, which regions, brands and cars really got more out of each gallon, and what did they give up to get there?**

### Questions answered

1. What did each region (USA, Europe, Japan) give up in power and weight to gain MPG?
2. Does more performance always cost fuel economy?
3. Which cars were both powerful **and** efficient for their year?
4. Which brands beat their expected MPG most often, and which fell furthest short?
5. Does the brand ranking change once weight is taken into account?
6. Was the big jump in average MPG in 1980 real, or a side effect of which cars are in the data?
7. Did diesel engines really deliver better economy?

---

## Tools and approach

| Step | Tool | What I did |
|---|---|---|
| Cleaning | Python (pandas) | Checked for duplicates and missing values, took the brand from each car name and fixed misspellings ("chevroelt", "toyouta", "maxda", "vokswagen"), filled 6 missing horsepower values with the brand's median, and added metric columns (kg, L/100 km) |
| Feature engineering | Python (pandas, NumPy) | Grouped years into three eras. For each model year, fitted MPG against weight to get an **expected MPG** for every car. **Efficiency gap = actual MPG − expected MPG**: a positive gap means the car beat a typical car of its weight and year. |
| Frontier | Python, checked again in SQL | Marked a car as **best in its year** when no other car from that year had both more MPG and more horsepower. 102 cars qualify, and the SQL check gives the same result. |
| Analysis | MySQL | Loaded the clean data, ran data checks, answered 13 questions using CTEs, window functions (`NTILE`, `RANK`, `ROW_NUMBER`, `LAG`) and `CASE` logic, and created 5 views exported for Tableau |
| Dashboard | Tableau | Built a two-page interactive report: an **Overview** of the main findings and a **Car Explorer** with filters |

### Eras

| Era | Years | Why |
|---|---|---|
| Cheap fuel | 1970–1973 | Before the first oil crisis |
| Oil crisis shock | 1974–1978 | After the 1973–74 oil embargo |
| Downsizing | 1979–1982 | Second oil shock and stricter fuel economy rules |

---

## Key findings

**1. US cars improved the most, but paid for it with power and weight.**
From the first era to the last, US cars gained **65%** in MPG, compared with 41% for Europe and 39% for Japan. They got there mostly by shrinking: horsepower fell by **34%** and weight by **22%**. European and Japanese cars lost about 15% of their horsepower and kept their weight about the same.

**2. The 1980 jump is mostly a sample effect.**
Average MPG jumps from 25.1 in 1979 to 33.7 in 1980. But **76%** of the 1980 cars in the data are imports, compared with 21% the year before. US cars on their own only moved from 23.5 to 25.9. The long-term trend is real; the sudden jump mostly isn't.

**3. Raw MPG and real efficiency rank brands very differently.**
- Fiat, Datsun and Peugeot beat their expected MPG by the widest margin.
- Mazda drops from **4th** by raw MPG to **15th** once weight is taken into account.
- Oldsmobile and Pontiac climb 6–7 places: heavy cars, but efficient for their weight.
- Ford has the largest total shortfall against expected MPG.

**4. Diesel looks promising, but the sample is small.**
The 9 diesel cars average **35.5 MPG** against 23.2 for petrol, and beat their expected MPG by about 7 MPG on average. With only 9 cars, this is a strong hint, not proof.

---

## Dashboard

**Page 1: Overview.** Headline KPIs, the MPG trend by region, what each region traded for MPG, and the 1980 sample-mix chart.

**Page 2: Car Explorer.** Filter by region, brand, fuel type and year to see the best cars of each year, how weight relates to MPG, and the cars that beat their expected MPG by the most.

![Car Explorer dashboard](automobile_project/images/car_explorer_dashboard.png)

---

## Repository structure

```
automobile_project/
├── data/
│   ├── raw/Automobile.csv               # original dataset
│   ├── processed/automobile_clean.csv   # output of the Python notebook
│   └── sql_outputs/                     # MySQL views exported for Tableau
│       ├── brand_rank_shift.csv
│       ├── brand_summary.csv
│       ├── origin_yearly_trend.csv
│       ├── region_tradeoff.csv
│       └── year_mix.csv
├── notebooks/
│   └── Automobile_analysis.ipynb        # cleaning and feature engineering
├── sql/
│   └── automobile_analysis.sql          # data checks, 13 questions, views
├── tableau/
│   └── Automobile_Project.twbx          # packaged Tableau workbook
└── images/                              # dashboard screenshots
```

---

## How to reproduce

1. **Python:** open `automobile_project/notebooks/Automobile_analysis.ipynb` in Google Colab, run all cells, and upload `Automobile.csv` when asked. The notebook creates `automobile_clean.csv`.
2. **MySQL:** in MySQL Workbench, run the first part of `automobile_project/sql/automobile_analysis.sql` to create the database and table. Import `automobile_clean.csv` with the **Table Data Import Wizard**, then run the rest of the script.
3. **Tableau:** open `automobile_project/tableau/Automobile_Project.twbx` in Tableau Desktop or Tableau Public. The data is packaged inside the file.

To run the notebook outside Colab, install the libraries with `pip install -r requirements.txt` and remove the `google.colab` lines.

---

## Limitations

- 398 cars is a sample, not every car sold, and some years have very few European or Japanese cars.
- Expected MPG only accounts for weight and model year. Transmission, body style and engine tuning are not in the data.
- The diesel group (9 cars) and the 3- and 5-cylinder groups are small, so results there should be read with care.

---

## Data source

Auto MPG dataset, originally from the [UCI Machine Learning Repository](https://archive.ics.uci.edu/dataset/9/auto+mpg).

## Author

**Venkata Praveen Jasthi** · [LinkedIn](www.linkedin.com/in/venkata-praveen-jasthi-825070357) · [Email](jasthipraveen8@gmail.com)
