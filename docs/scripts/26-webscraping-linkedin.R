## ----webscraping-linkedin, include=FALSE--------------------------------------------------------------------------------------------
chap <- 27
lc <- 0
rq <- 0
# **`r paste0("(LC", chap, ".", (lc <- lc + 1), ")")`**
# **`r paste0("(RQ", chap, ".", (rq <- rq + 1), ")")`**

knitr::opts_chunk$set(
  tidy = FALSE, 
  out.width = '\\textwidth', 
  fig.height = 4,
  warning = FALSE
  )

options(scipen = 99, digits = 3)

# Set random number generator see value for replicable pseudorandomness. Why 76?
# https://www.youtube.com/watch?v=xjJ7FheCkCU
set.seed(76)


## -----------------------------------------------------------------------------------------------------------------------------------
library(tidyverse)     # General purpose data wrangling
library(rvest)         # Parsing of html/xml files
library(rebus)         # Verbose regular expressions


## -----------------------------------------------------------------------------------------------------------------------------------

get_last_page <- function(html){
    
    pages_data <- html %>% 
        html_nodes('.pagination-page') %>% # The '.' indicates the class
        html_text()                        # Extracts the raw text as a list
    
    pages_data[(length(pages_data)-1)] %>%             # The second to last of the buttons is the one
        unname() %>%                                     # Take the raw string
        as.numeric()                                     # Convert to number
}

get_reviews <- function(html){
    html %>% 
        html_nodes('.review-info__body__text') %>%       # The relevant tag
        html_text() %>% 
        str_trim() %>%                       # Trims additional white space
        unlist()                             # Converts the list into a vector
}

get_reviewer_names <- function(html){
    html %>% 
        html_nodes('.consumer-info__details__name') %>% 
        html_text() %>% 
        str_trim() %>% 
        unlist()
}

get_review_dates <- function(html){
    
    status <- html %>% 
        html_nodes('time') %>% 
        html_attrs() %>%              # The status information is this time a tag attribute
        map(2) %>%                    # Extracts the second element
        unlist() 
    
    dates <- html %>% 
        html_nodes('time') %>% 
        html_attrs() %>% 
        map(1) %>% 
        ymd_hms() %>%                 # Using a lubridate function 
        # to parse the string into a datetime object
        unlist()
    
    return_dates <- tibble(status = status, dates = dates) %>%   # You combine the status and the date 
        # information to filter one via the other
        filter(status == 'ndate') %>%              # Only these are actual reviews
        pull(dates) %>%                            # Selects and converts to vector
        as.POSIXct(origin = '1970-01-01 00:00:00') # Converts datetimes to POSIX objects
    
    # The lengths still occasionally do not lign up. You then arbitrarily crop the dates to fit
    # This can cause data imperfections, however reviews on one page are generally close in time)
    
    length_reviews <- length(get_reviews(html))
    
    return_reviews <- if (length(return_dates)> length_reviews){
        return_dates[1:length_reviews]
    } else{
        return_dates
    }
    return_reviews
}

get_star_rating <- function(html){
    
    
    # The pattern we look for
    pattern = 'star-rating-'%R% capture(DIGIT)  
    
    vector <- html %>% 
        html_nodes('.star-rating') %>% 
        html_attr('class') %>% 
        str_match(pattern) %>% 
        map(1) %>% 
        as.numeric()  
    vector <-  vector[!is.na(vector)]
    vector <- vector[3:length(vector)]
    vector
}

get_data_table <- function(html, company_name){
    
    # Extract the Basic information from the HTML
    reviews <- get_reviews(html)
    reviewer_names <- get_reviewer_names(html)
    dates <- get_review_dates(html)
    ratings <- get_star_rating(html)
    
    # Minimum length
    min_length <- min(length(reviews), length(reviewer_names), length(dates), length(ratings))
    
    # Combine into a tibble
    combined_data <- tibble(reviewer = reviewer_names[1:min_length],
                            date = dates[1:min_length],
                            rating = ratings[1:min_length],
                            review = reviews[1:min_length]) 
    
    # Tag the individual data with the company name
    combined_data %>% 
        mutate(company = company_name) %>% 
        select(company, reviewer, date, rating, review)
}

get_data_from_url <- function(url, company_name){
    html <- read_html(url)
    get_data_table(html, company_name)
}

scrape_write_table <- function(url, company_name){
    
    # Read first page
    first_page <- read_html(url)
    
    # Extract the number of pages that have to be queried
    latest_page_number <- get_last_page(first_page)
    
    # Generate the target URLs
    list_of_pages <- str_c(url, '?page=', 1:latest_page_number)
    
    # Apply the extraction and bind the individual results back into one table, 
    # which is then written as a tsv file into the working directory
    list_of_pages %>% 
        map(get_data_from_url, company_name) %>%  # Apply to all URLs
        bind_rows() %>%                           # Combines the tibbles into one tibble
        write_tsv(str_c(company_name,'.tsv'))     # Writes a tab separated file
}


# url <-'http://www.trustpilot.com/review/www.amazon.com'
# scrape_write_table(url, 'amazon')
# amazon_table <- read_tsv('amazon.tsv')


