# Overview

As a backend developer who works mostly in JavaScript and TypeScript, I wanted to learn R, a language built for working with data. I learn best by building something real, so instead of only working through small examples, I wrote a complete program that uses R's core features: variables, expressions, conditionals, loops, functions, and its main data structures.

NutriCheck is a console program for tracking what you eat in a day. It loads a list of common Nigerian and Brazilian foods (jollof rice, eba, moi moi, feijão, pão de queijo and more) from a CSV file. You can add foods with any number of servings, see a report comparing your totals for calories, protein, carbohydrates, fat and sodium with daily targets, undo the last entry, and save the day's log to a CSV file.

To run it, open a terminal in the project folder and run `Rscript nutricheck.R`. Then choose options from the menu: 1 to see the food list, 2 to add a food by its number or name, 3 to view the daily report, 4 to undo the last entry, 5 to save the log, and q to quit.

My purpose for writing this software was to learn how R handles data differently from the languages I already know, using a topic close to my background in food technology. I also plan to build on this program later to analyze eating patterns over time.

[Software Demo Video](https://youtu.be/Uae6NI_s_Jg)

# Development Environment

I wrote the code in Visual Studio Code with the R extension, ran it from the terminal with Rscript, and used Git and GitHub for version control.

The program is written in R 4.6 and uses only base R, so there are no packages to install. It uses data frames to hold the food list, named vectors for the daily targets and nutrient totals, and lists for the meal log. The food data lives in `foods.csv`, and nutrient values are approximate per typical serving.

# Useful Websites

* [The R Project](https://www.r-project.org/)
* [An Introduction to R (official manual)](https://cran.r-project.org/doc/manuals/r-release/R-intro.html)
* [R for Data Science (2e)](https://r4ds.hadley.nz/)
* [R in Visual Studio Code](https://code.visualstudio.com/docs/languages/r)

# Future Work

* Let the user set their own daily targets based on age, weight and activity level.
* Load saved meal logs from previous days and show trends over a week.
* Add more foods and allow users to add their own foods to the list.