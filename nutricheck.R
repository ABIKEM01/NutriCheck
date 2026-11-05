# nutricheck.R
# NutriCheck: a console program that lets you build a day's meals from a
# list of Nigerian and Brazilian foods and compares the totals with daily
# nutrient targets.
#
# Run it from the terminal with:  Rscript nutricheck.R
#
# Nutrient values in foods.csv are approximate, per typical serving.
#
# R data types used in this program:
#   character - food names, labels and user input
#   numeric   - nutrient values, targets, servings and percentages (doubles)
#   integer   - food numbers in the list and the maximum servings (10L)
#   logical   - TRUE/FALSE flags and every condition the program checks
#   factor    - the food categories (Grains, Fruits, Proteins, ...)
#   Date      - today's date, shown in the report and saved in the log
# Data structures: named vectors, lists and data frames.

# ---------------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------------

# File paths are stored in variables so they are easy to change later.
FOOD_FILE <- "foods.csv"
LOG_FILE  <- "meal_log.csv"

# The most servings of one food allowed in a single entry. The "L" suffix
# makes this an integer instead of R's default numeric (double) type.
MAX_SERVINGS <- 10L

# A logical flag that turns the advice lines in the report on or off.
SHOW_TIPS <- TRUE

# The nutrients the program tracks, in the order they are reported.
NUTRIENTS <- c("calories", "protein_g", "carbs_g", "fat_g", "sodium_mg")

# Daily targets as a named numeric vector. The names let us look a value up
# by nutrient, e.g. DAILY_TARGETS["protein_g"].
DAILY_TARGETS <- c(
  calories  = 2000,
  protein_g = 50,
  carbs_g   = 275,
  fat_g     = 78,
  sodium_mg = 2300
)

# Friendly labels used when printing the report.
LABELS <- c(
  calories  = "Calories (kcal)",
  protein_g = "Protein (g)",
  carbs_g   = "Carbohydrates (g)",
  fat_g     = "Fat (g)",
  sodium_mg = "Sodium (mg)"
)

# One connection to standard input, opened once, so user input works when
# the program is run with Rscript (readline() only works in an R console).
STDIN <- file("stdin")
open(STDIN)

# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------

# Prints a prompt and returns what the user typed, trimmed of spaces.
# Returns "q" if the input stream ends, so the program can exit cleanly.
read_input <- function(prompt) {
  cat(prompt)
  line <- readLines(STDIN, n = 1)
  if (length(line) == 0) {
    return("q")
  }
  trimws(line)
}

# Reads the food list from a CSV file into a data frame and checks that
# every column the program needs is present.
load_foods <- function(path = FOOD_FILE) {
  if (!file.exists(path)) {
    stop("Could not find the food file: ", path)
  }
  foods <- read.csv(path, stringsAsFactors = FALSE)
  missing <- setdiff(c("food", "category", "serving", NUTRIENTS), names(foods))
  if (length(missing) > 0) {
    stop("The food file is missing columns: ", paste(missing, collapse = ", "))
  }
  # Store the category as a factor: a fixed set of labels, kept in the
  # order they first appear in the file.
  foods$category <- factor(foods$category, levels = unique(foods$category))
  foods
}

# Prints the numbered food list, grouped by category.
show_foods <- function(foods) {
  cat("\nAvailable foods\n")
  for (category in levels(foods$category)) {
    cat("\n ", category, "\n", sep = "")
    rows <- which(foods$category == category)
    for (i in rows) {
      cat(sprintf("  %2d. %-28s %s\n", i, foods$food[i], foods$serving[i]))
    }
  }
}

# Finds a food by its number in the list or by (part of) its name.
# Returns the row number, or NA if nothing matches.
find_food <- function(foods, choice) {
  number <- suppressWarnings(as.integer(choice))
  if (!is.na(number)) {
    if (number >= 1 && number <= nrow(foods)) {
      return(number)
    }
    return(NA)
  }
  matches <- grep(choice, foods$food, ignore.case = TRUE)
  if (length(matches) == 1) {
    return(matches)
  } else if (length(matches) > 1) {
    cat("That matches more than one food:",
        paste(foods$food[matches], collapse = ", "), "\n")
  }
  NA
}

# Adds a food to the meal log and returns the updated log. R copies the
# list when we modify it, so the caller must keep the returned value.
add_food <- function(meal_log, foods, row, servings = 1) {
  nutrients <- unlist(foods[row, NUTRIENTS]) * servings
  entry <- list(food = foods$food[row], servings = servings, nutrients = nutrients)
  meal_log[[length(meal_log) + 1]] <- entry
  meal_log
}

# Adds up every nutrient across all entries in the meal log.
calculate_totals <- function(meal_log) {
  totals <- setNames(rep(0, length(NUTRIENTS)), NUTRIENTS)
  for (entry in meal_log) {
    totals <- totals + entry$nutrients
  }
  totals
}

# Describes how a total compares with its target. For fat and sodium,
# going over is a warning; for the others, falling short is the concern.
nutrient_status <- function(nutrient, value, target) {
  percent <- value / target * 100
  if (nutrient %in% c("fat_g", "sodium_mg") && percent > 100) {
    "Over the limit"
  } else if (percent > 110) {
    "Above target"
  } else if (percent >= 80) {
    "On track"
  } else if (percent >= 50) {
    "A bit low"
  } else {
    "Low"
  }
}

# Prints what was eaten and how each nutrient compares with its target.
print_report <- function(meal_log, targets = DAILY_TARGETS) {
  if (length(meal_log) == 0) {
    cat("\nNothing logged yet. Add a food first.\n")
    return(invisible(NULL))
  }
  cat("\nToday's meals\n")
  for (entry in meal_log) {
    cat(sprintf("  - %s x %g\n", entry$food, entry$servings))
  }
  totals <- calculate_totals(meal_log)
  today <- Sys.Date()  # a Date object
  cat("\nDaily report for", format(today, "%A, %d %B %Y"), "\n")
  cat(sprintf("  %-18s %8s %8s %6s  %s\n", "Nutrient", "Total", "Target", "%", "Status"))
  for (n in NUTRIENTS) {
    percent <- round(totals[[n]] / targets[[n]] * 100)
    cat(sprintf("  %-18s %8.1f %8.0f %5d%%  %s\n", LABELS[[n]], totals[[n]],
                targets[[n]], percent, nutrient_status(n, totals[[n]], targets[[n]])))
  }
  if (SHOW_TIPS) {
    print_tips(totals, targets)
  }
  invisible(totals)
}

# Prints short advice based on the totals. Each comparison below produces
# a logical value (TRUE or FALSE) that decides whether a tip is shown.
print_tips <- function(totals, targets) {
  over_sodium <- totals[["sodium_mg"]] > targets[["sodium_mg"]]
  low_protein <- totals[["protein_g"]] < targets[["protein_g"]] * 0.8
  if (over_sodium) {
    cat("  Tip: sodium is over the limit. Go easy on salty soups and seasoning cubes.\n")
  }
  if (low_protein) {
    cat("  Tip: protein is low. Beans, moi moi, eggs or chicken would help.\n")
  }
  if (!over_sodium && !low_protein) {
    cat("  Nice work: protein and sodium are both in a good range.\n")
  }
}

# Removes the most recent entry from the meal log and returns the new log.
undo_last <- function(meal_log) {
  if (length(meal_log) == 0) {
    cat("There is nothing to undo.\n")
    return(meal_log)
  }
  cat("Removed:", meal_log[[length(meal_log)]]$food, "\n")
  meal_log[-length(meal_log)]
}

# Saves the meal log to a CSV file, one row per food eaten.
save_log <- function(meal_log, path = LOG_FILE) {
  if (length(meal_log) == 0) {
    cat("There is nothing to save yet.\n")
    return(invisible(FALSE))
  }
  rows <- lapply(meal_log, function(entry) {
    data.frame(date = format(Sys.Date()), food = entry$food,
               servings = entry$servings, t(entry$nutrients))
  })
  write.csv(do.call(rbind, rows), path, row.names = FALSE)
  cat("Saved", length(meal_log), "entries to", path, "\n")
  invisible(TRUE)
}

# Asks which food to add and how many servings, then returns the new log.
prompt_add_food <- function(meal_log, foods) {
  choice <- read_input("Food number or name: ")
  row <- find_food(foods, choice)
  if (is.na(row)) {
    cat("Sorry, I couldn't find that food. Try option 1 to see the list.\n")
    return(meal_log)
  }
  servings <- suppressWarnings(as.numeric(read_input("Servings (e.g. 1 or 0.5): ")))
  if (is.na(servings) || servings <= 0) {
    cat("Servings must be a number greater than zero.\n")
    return(meal_log)
  } else if (servings > MAX_SERVINGS) {
    cat("Please enter", MAX_SERVINGS, "servings or fewer.\n")
    return(meal_log)
  }
  cat(sprintf("Added %g x %s.\n", servings, foods$food[row]))
  add_food(meal_log, foods, row, servings)
}

# Runs the main menu until the user chooses to quit.
main <- function() {
  foods <- load_foods()
  meal_log <- list()
  cat("Welcome to NutriCheck!\n")

  repeat {
    cat("\n1) Show foods  2) Add food  3) View report  4) Undo last  5) Save log  q) Quit\n")
    choice <- tolower(read_input("Choose an option: "))

    if (choice == "1") {
      show_foods(foods)
    } else if (choice == "2") {
      meal_log <- prompt_add_food(meal_log, foods)
    } else if (choice == "3") {
      print_report(meal_log)
    } else if (choice == "4") {
      meal_log <- undo_last(meal_log)
    } else if (choice == "5") {
      save_log(meal_log)
    } else if (choice == "q") {
      cat("Goodbye! Eat well.\n")
      break
    } else {
      cat("Please choose 1-5 or q.\n")
    }
  }
}

main()
