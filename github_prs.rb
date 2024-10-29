# This script fetches pull request (PR) data from a specified GitHub repository, processes the data, 
# and outputs it to a CSV file. The data includes information such as PR author, status, title, and creation date.

# The script accepts arguments for the repository name, an API token for authentication, 
# the output CSV file name, and an optional page number for pagination.

# Usage Example:
# ruby github_prs.rb <github_repo_name> <github_api_token> <output_file_name> <page_number? = 1>

# Example:
# ruby github_prs.rb rails/rails 1234567890abcdefg rails_mergers.csv 1

# Note:
#   - Make sure to generate a GitHub API token with 'repo' permissions and set it as an environment variable.
#   - The script handles rate limits, checking them to avoid overloading the GitHub API.
#   - JSON files of each API response page are stored in a subfolder.

# Required Libraries
require 'json'   # Handles JSON parsing and generation
require 'net/http' # Manages HTTP requests and responses
require 'uri'    # Provides URI handling for HTTP requests
require 'csv'    # Allows CSV file manipulation

# Uncomment the following lines if using debugging tools or advanced argument parsing (optional):
# require 'pry'      # A debugging library (optional)
# require 'optparse' # A library to handle command-line options (optional)

# Class: Arguments
# Handles input arguments provided via the command line and validates them.
# Expected arguments: repo_name, output_file_name, optional page_number.
class Arguments
    attr_reader :repo_name, :output_file_name, :page_number, :github_api_token

    # Initializes and validates the arguments.
    def initialize
        # Assigns the first argument as the GitHub repo name.
        @repo_name = ARGV[0]

        # Assigns the second argument as the output CSV file name.
        @output_file_name  = ARGV[1]

        # Sets the page number for API pagination (default is 1).
        @page_number = ARGV[2] || 1

        # Fetches the GitHub API token from the environment variables.
        @github_api_token = ENV["GITHUB_API_TOKEN"]

        # Checks that all required arguments are provided.
        check_for_all_arguments
        print_execution_message
    end

    private

    # Verifies that all necessary arguments are present; raises an error if any are missing.
    def check_for_all_arguments
        # Custom error messages for missing arguments.
        if @repo_name.nil? || @output_file_name.nil? || @github_api_token.nil?
            raise ArgumentError.new("You must provide 2 arguments: repo name, output file name, and optionally page number") unless ARGV.length >= 2
            raise ArgumentError.new("Please provide a GitHub API token like GITHUB_API_TOKEN=<your_token>") unless github_api_token
            raise ArgumentError.new("Please provide a repo name") unless repo_name
            raise ArgumentError.new("Please provide an output file name") unless output_file_name
        end
    end

    # Prints a message confirming the script is starting the PR data search.
    def print_execution_message
        puts "Searching for pull requests on #{@repo_name} and saving to #{@output_file_name}"
    end
end

# TODO Use me to coordinate the file saving
# class FolderHandler
#     def initialize(folder_name)
#         @folder_name = folder_name
#         check_or_create_folder unless Dir.exist?(@folder_name)
#     end
    
#     private 
#     def check_or_create_folder
#         # if the folder exists, print a message
#         # else create the folder
#         if Dir.exist?(@folder_name)
#             puts "Folder #{@folder_name} already exists" if Dir.exist?(@folder_name)
#         else
#             Dir.mkdir(@folder_name)
#             print_execution_message
#         end
#     end

#     def print_execution_message
#         puts "Created folder #{@folder_name}"
#     end
# end

# class to handle the csv file
# Class: CsvHandler
# Manages the creation and updating of the CSV output file, including headers and data rows.
class CsvHandler
    attr_reader :csv_name

    # Initializes the CSV file handler, setting up headers if needed.
    def initialize(csv_name, headers)
        @csv_name = csv_name
        @headers = headers
        check_or_create_file
    end

    # Adds rows to the CSV file, typically one row per pull request.
    def add_rows_to_csv(rows)
        CSV.open(@csv_name, "a+") do |csv|
            rows.each do |row|
                csv << row
            end
            puts "Added #{rows.length} rows to #{@csv_name}"
        end
    end

    private

    # Checks if the file exists; if not, it creates the file and adds headers.
    def check_or_create_file
        if File.exist?(@csv_name)
            puts "File #{@csv_name} already exists"
        else
            initialize_csv_headers
            print_creation_message
        end
    end

    # Prints a message when the CSV file is created.
    def print_creation_message
        puts "Created file #{@csv_name}"
    end

    # Initializes the CSV with the provided headers.
    def initialize_csv_headers
        puts "Initializing CSV headers: #{@headers}"
        CSV.open(@csv_name, "a+") do |csv|
            csv << [*@headers]
        end
    end
end

# Class: GithubPullRequestResponse
# Represents the response from the GitHub API and checks rate limits to avoid hitting API restrictions.
class GithubPullRequestResponse
    attr_reader :response, :body, :page_number, :last_page, :header

    # Initializes the response and extracts relevant data.
    def initialize(response, page_number)
        @response = response
        @page_number = page_number
        @last_page = parse_link_for_last_page_number
        @body = response.body
        @header = response.header
        check_header_for_rate_limit
    end

    private

    # Parses the response header to find the total number of pages.
    def parse_link_for_last_page_number
        last_page_number = response.header['link'].split(",")[1].split(";")[0].split("&page=").last.split("&")[0].to_i
        puts "Last page number: #{last_page_number}"
        last_page_number
    end

    # Checks API rate limits in the response header and warns or stops if limits are low.
    def check_header_for_rate_limit
        rate_limit = response.header['x-ratelimit-limit'].to_i
        puts "Warning: rate limit is #{rate_limit}" if rate_limit < 1000
        raise "Rate limit is #{rate_limit}. Please wait an hour and try again." if rate_limit < 500
    end
end

# Function: save_response_to_file
# Saves the body and headers of a GitHub API response to JSON files, organized by page number.
def save_response_to_file(response, page_number = 1)
    # Save the response body as JSON.
    save_json_response_to_file(response.body, "github_pull_requests_response_page_#{page_number}.json", page_number)

    # Save the response headers as JSON.
    save_json_response_to_file(response.header.each_header {|key,value| "#{key} = #{value}" }, "github_pull_requests_response_headers_page_#{page_number}.json", page_number)
end

# Function: save_json_response_to_file
# Accepts JSON data and saves it to a specified file in a designated subfolder.
    def save_json_response_to_file(response_data, output_file_name, page_number)
        subfolder = "json_outputs"
    Dir.mkdir(subfolder) unless Dir.exist?(subfolder) # Creates a subfolder for output if it doesn't exist
    file_name = "#{subfolder}/" + find_new_file_name(output_file_name, page_number)
        File.open(file_name, "w") do |f|
            f.write(response_data)
        end
    end

# Function: build_query_parameters_hash
# Builds a hash of query parameters for the GitHub API request.
# Includes pagination, state of pull requests, sorting method, and results per page.
def build_query_parameters_hash(page_number)
    # Date Range (uncomment if filtering by date is needed)
    # one_year_ago = (Date.today - 365).to_datetime.iso8601
    # one_month_ago = (Date.today - 30).to_datetime.iso8601
    # today = (Date.today).to_datetime.iso8601

    query_hash = {
        # since: one_month_ago,  # Uncomment to filter by a specific start date
        # until: today,          # Uncomment to filter by a specific end date
        state: 'all',            # Fetches all pull requests, regardless of state (open, closed, merged)
        per_page: 100,           # Maximum results per page
        page: page_number,       # Current page number for pagination
        sort: 'created'          # Sorts by creation date
    }
    return query_hash
end

# make the request to the github api to find the pull requests
# def make_request(uri, github_api_token)
#     request = Net::HTTP::Get.new(uri)
#     request["Authorization"] = "token #{github_api_token}"
#     request["Accept"] = "application/vnd.github.v3+json"
#     request["User-Agent"] = "Ruby"
#     req_options = { use_ssl: uri.scheme == "https" }

#     response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
#         http.request(request)
#     end
#     return response
# end

# Function: make_uri
# Constructs the URI for the GitHub API request using the repository name and query parameters.
# This function combines the GitHub API URL with the encoded query parameters.
def make_uri(query_hash, repo_name)
    uri = URI::HTTPS.build(
        host: 'api.github.com',
        query: URI.encode_www_form(query_hash),
        path: "/repos/#{repo_name}/pulls"
    )
    return uri
end

# Class: GithubApiRequest
# Handles the construction and sending of a GitHub API request to retrieve pull request data.
# Takes in a URI, GitHub API token, and page number to paginate through results.
class GithubApiRequest
    attr_reader :uri, :request, :response

    def initialize(uri, github_api_token, page_number)
        @uri = uri
        @request = make_request(uri, github_api_token)
        @response = GithubPullRequestResponse.new(@request, page_number)
    end

    private

    # Function: make_request
    # Configures and sends an HTTP GET request to the GitHub API with the provided API token.
    # Sets necessary headers, including authorization and user-agent.
    def make_request(uri, github_api_token)
        request = Net::HTTP::Get.new(uri)
        request["Authorization"] = "token #{github_api_token}"
        request["Accept"] = "application/vnd.github.v3+json"
        request["User-Agent"] = "Ruby"
        req_options = { use_ssl: uri.scheme == "https" }
        puts "Making request to #{uri}"

        response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
            http.request(request)
        end
        return response
    end
end

# Function: collect_page_of_pull_requests_from_github_api
# Orchestrates the API request for a single page of pull requests.
# Uses other helper functions to build query parameters, create the URI, and fetch responses.
def collect_page_of_pull_requests_from_github_api(repo_name, github_api_token, page_number = 1)
    query_hash = build_query_parameters_hash(page_number) 
	uri = make_uri(query_hash, repo_name)

    # Sends the request and receives the response
    api_request = GithubApiRequest.new(uri, github_api_token, page_number)
    github_api_response = api_request.response
    # github_pull_requests_response = GithubPullRequestResponse.new(response, page_number)
    
    # Saves the response to JSON files
    save_response_to_file(github_api_response, page_number)
	return github_api_response
end

# Function: find_new_file_name
# Checks if a file name already exists and generates a new file name if necessary.
# This prevents overwriting existing files by appending an attempt number and page number.
def find_new_file_name(file_name, page_number, attempt = 0)
    if File.exist?(file_name)
        next_file_name = file_name.split(".json")[0] + "_#{attempt}_#{page_number}.json"
        attempt += 1
        find_new_file_name(next_file_name, page_number, attempt)
    else
        return file_name
    end
end

# Function: details_from_pull_request
# Extracts specific fields from a pull request JSON object.
# Returns an array of selected details, such as author, status, creation date, and other metadata.
def details_from_pull_request(pull_request)
    pr_node_id = pull_request['node_id']
    pr_number = pull_request['number']
    title = pull_request['title']
    author = pull_request['user']['login']
	status = pull_request['state']
    user_node_id = pull_request['user']['node_id']
    created_at = pull_request['created_at']
    merged_at = pull_request['merged_at'] || "not merged"
    author_association = pull_request['author_association']
    base_label = pull_request['base']['label']
    closed_at = pull_request['closed_at'] || "not closed"
    is_draft = pull_request['draft'] || false
    is_locked = pull_request['locked'] || false
    count_reviews_requested = pull_request['requested_reviewers'].length

	return [
        pr_node_id,
        pr_number,
        base_label,
        created_at, 
        title, 
        merged_at,
        status,
        closed_at,
        author, 
        user_node_id,
        author_association,
        is_draft,
        is_locked,
        count_reviews_requested
    ]
end

# Function: export_pull_request_author_and_status_to_csv
# The main function that coordinates the data retrieval and export process.
# It initializes the arguments, retrieves pull requests, and writes data to a CSV file.
def export_pull_request_author_and_status_to_csv
    # Sets up command-line arguments
    args = Arguments.new
    repo_name = args.repo_name
    output_file_name = args.output_file_name
    page_number = args.page_number
    github_api_token = args.github_api_token
	
    # Initializes the CSV file with headers
    csv = CsvHandler.new(output_file_name, [
        'pr node_id',
                                                'pr_number',
                                                'base_label',
                                                'created_at',
                                                'pr_title',
                                                'pr_is_merged?',
                                                'status',
                                                'closed_at',
                                                'author',
                                                'author_node_id',
                                                'author_association',
                                                'is_draft',
                                                'is_locked',
                                                'count_reviews_requested'
                                            ])

    # Pagination loop to process all pages of pull requests
    last_queried_page = 0
    total_pages = 0
    while last_queried_page < total_pages || total_pages == 0
        # Collects pull requests for the current page
        puts "Collecting page #{page_number} of pull requests"
        response = collect_page_of_pull_requests_from_github_api(repo_name, github_api_token, page_number)
        # collect the pull requests from the github api
        pull_requests = JSON.parse(response.body)

        # Adds the pull request data to the CSV file
        csv.add_rows_to_csv(pull_requests.map { |pull_request| details_from_pull_request(pull_request) })

        # Updates pagination status
        last_queried_page = response.page_number
        # update the total pages
        total_pages = response.last_page
        # increment the page number
        page_number += 1

        puts "Last queried page: #{last_queried_page}"
        puts "Total pages: #{total_pages}"
    end
 
end

# Entry point: runs the script to export pull request data to CSV
export_pull_request_author_and_status_to_csv

