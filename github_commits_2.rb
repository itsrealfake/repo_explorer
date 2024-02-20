# The script will accept a repo name, an API token, and the name of the output file. 
# 
# The script will find the pull requests on a repo for a given date range, and output the author and status of the pull request to a csv.
#
# Usage:
# ruby github_prs.rb <github_repo_name> <github_api_token> <output_file_name> <page_number? = 1>
# 
# Example:
# ruby github_prs.rb rails/rails 1234567890abcdefg rails_mergers.csv 1
#
# TODO: 
#   - determine a nice pattern for the file names & folders
#   - what else?
#

require 'json'
require 'net/http'
require 'uri'
require 'csv'
require 'pry'
# require 'optparse' TODO: use this to parse the args


# class for the arguments
class Arguments
    attr_reader :repo_name, :output_file_name, :page_number, :github_api_token
    def initialize
        @repo_name = ARGV[0]
        @output_file_name  = ARGV[1]
        @page_number = ARGV[2] || 1
        @github_api_token = ENV["GITHUB_API_TOKEN"]
        check_for_all_arguments
        print_execution_message
    end

    private

    def check_for_all_arguments
        if @repo_name.nil? || @output_file_name.nil? || @github_api_token.nil?
            raise ArgumentError.new("You must provide 2 arguments: repo name, output file name, and optionally page number") unless ARGV.length >= 2
            raise ArgumentError.new("Please provide a github api token like GITHUB_API_TOKEN=<your_token>") unless github_api_token
            raise ArgumentError.new("Please provide a repo name") unless repo_name
            raise ArgumentError.new("Please provide an output file name") unless output_file_name
        end
    end

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
class CsvHandler
    attr_reader :csv_name
    def initialize(csv_name, headers)
        @csv_name = csv_name
        @headers = headers
        check_or_create_file
        
        
    end

    def add_rows_to_csv(rows)
        CSV.open(@csv_name, "a+") do |csv|
            rows.each do |row|
                csv << row
            end
            puts "Added #{rows.length} rows to #{@csv_name}"
        end
    end

    private

    def check_or_create_file
        # if the file exists, print a message
        # else create the file
        if File.exist?(@csv_name)
            puts "File #{@csv_name} already exists"
        else
            initialize_csv_headers
            print_creation_message
        end
    end

    def print_creation_message
        puts "Created file #{@csv_name}"
    end

    def initialize_csv_headers
        puts "initializing csv headers: #{@headers}"
        CSV.open(@csv_name, "a+") do |csv|
            csv << [*@headers]
        end
    end
end


# a class representing the github api response
class GithubApiResponse
    attr_reader :response, :body, :page_number, :last_page, :header
    def initialize(response, page_number)
        @response = response
        @page_number = page_number
        @last_page = parse_link_for_last_page_number
        @body = response.body
        @header = response.header

        check_header_for_rate_limit
    end

    private

    def parse_link_for_last_page_number
        # parse the link header for the last page number
        last_page_number = response.header['link'].split(",")[1].split(";")[0].split("&page=").last.split("&")[0].to_i
        puts "Last page number: #{last_page_number}"
        last_page_number
    end

    def check_header_for_rate_limit
        # check the response header for the rate limit
        rate_limit = response.header['x-ratelimit-limit'].to_i
        # if the rate limit is below 1000 warn the user
        puts "Warning: rate limit is #{rate_limit}" if rate_limit < 1000
        # if the rate limit is below 500 stop the script
        raise "Rate limit is #{rate_limit}. Please wait an hour and try again." if rate_limit < 500
    end



end


def save_response_to_file(response, page_number = 1)
    # save the response body to disk
    save_json_response_to_file(response.body, "github_commits_response_page_#{page_number}.json", page_number)
    # save the headers to disk

    save_json_response_to_file(response.header.each_header {|key,value| "#{key} = #{value}" }, "github_commits_response_headers_page_#{page_number}.json", page_number)
end
    # accepts a json response body and saves it to a file
    def save_json_response_to_file(response_data, output_file_name, page_number)
        file_name = find_new_file_name(output_file_name, page_number)
        File.open(file_name, "w") do |f|
            f.write(response_data)
        end
    end

# build the query parameters hash
def build_query_parameters_hash(page_number)
    query_hash = {
        # since: one_month_ago,
        # until: today,
        # state: 'all',
        per_page: 100,
        page: page_number,
        # sort: 'created'
    }
    return query_hash
end

def make_uri(query_hash, repo_name, uri_kind)
    raise ArgumentError.new("must be one of 'pulls' or 'commits'") unless %w[pulls commits].include?(uri_kind)
    uri = URI::HTTPS.build(
        host: 'api.github.com',
        query: URI.encode_www_form(query_hash),
        path: "/repos/#{repo_name}/#{uri_kind}"
    )
    return uri
end

# A github api request class
class GithubApiRequest
    attr_reader :uri, :request, :response
    def initialize(uri, github_api_token, page_number)
        @uri = uri
        @request = make_request(uri, github_api_token)
        @response = GithubApiResponse.new(@request, page_number)
    end

    private

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

# find all the pull requests for the repo within the time frame
def collect_page_results_from_github_api(repo_name, github_api_token, page_number = 1)
    query_hash = build_query_parameters_hash(page_number) 
	
    uri = make_uri(query_hash, repo_name,'commits') # TODO make this toggle between commits and pulls

    api_request = GithubApiRequest.new(uri, github_api_token, page_number) # TODO refactor this page_number thign
    github_api_response = api_request.response

    save_response_to_file(github_api_response, page_number)
	return github_api_response
end

# looks for a file in a folder, and returns a new file name if that one is taken
def find_new_file_name(file_name, page_number, attempt = 0)
    if File.exist?(file_name)
        next_file_name = file_name.split(".json")[0] + "_#{attempt}_#{page_number}.json"
        attempt += 1
        find_new_file_name(next_file_name, page_number, attempt)
    else
        return file_name
    end
end



# finds the author, and status of a pull request from an api response
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

# a wrapper function and exports the pull request author & status to a csv
def export_pull_request_author_and_status_to_csv
    
    # set arguments from the command line
    args = Arguments.new
    repo_name = args.repo_name
    output_file_name = args.output_file_name
    page_number = args.page_number
    github_api_token = args.github_api_token
	
    # create a CSV file and add the headers
    csv = CsvHandler.new(output_file_name, [    'pr node_id',
                                                'pr number',
                                                'base_label',
                                                'created_at',
                                                'pr title',
                                                'pr is merged?',
                                                'status',
                                                'closed_at',
                                                'author',
                                                'author node_id',
                                                'author_association',
                                                'is_draft',
                                                'is_locked',
                                                'count_reviews_requested'
                                            ])

    
    # while the current page number is less than the last page number
    last_queried_page = 0
    total_pages = 0
    while last_queried_page < total_pages || total_pages == 0
        # collect the pull requests from the github api
        puts "Collecting page #{page_number} of pull requests"
        response = collect_page_results_from_github_api(repo_name, github_api_token, page_number)
        # collect the pull requests from the github api
        pull_requests = JSON.parse(response.body)
        # add the pull requests to the csv
        csv.add_rows_to_csv(pull_requests.map { |pull_request| details_from_pull_request(pull_request) })
        # update the last queried page
        last_queried_page = response.page_number
        # update the total pages
        total_pages = response.last_page
        # increment the page number
        page_number += 1
        puts "Last queried page: #{last_queried_page}"
        puts "Total pages: #{total_pages}"
    end
 
end

## Run the script
# export_pull_request_author_and_status_to_csv

commits_by_contributor = Hash.new(0)

def export_commit_author_and_status_to_csv
    # set arguments from the command line
    args = Arguments.new
    repo_name = args.repo_name
    output_file_name = args.output_file_name
    page_number = args.page_number
    github_api_token = args.github_api_token

    # create a CSV file and add the headers
    commits_csv_headers = %w[commit_sha commit_node_id commit_comment_count commit_author_login commit_commiter_login commit_author_node_id commit_commiter_node_id commit_author_url commit_commiter_url commit_author_type commit_author_site_admin commit_commiter_type commit_commiter_site_admin commit_message commit_verification commit_verification_reason commit_verification_signature commit_status]
    csv = CsvHandler.new(output_file_name, commits_csv_headers)

    # while the current page number is less than the last page number
    last_queried_page = 0
    total_pages = 0
    while last_queried_page < total_pages || total_pages == 0
        # collect the pull requests from the github api
        begin
            puts "Collecting page #{page_number} of commits"
            response = collect_page_results_from_github_api(repo_name, github_api_token, page_number) # TODO refactor to send toggle value
            # collect the pull requests from the github api
            page_number += 1

            commits_response = JSON.parse(response.body)
            # add the pull requests to the csv
            csv.add_rows_to_csv(commits_response.map { |commit| details_from_commit_response(commit) })

            # update the last queried page
            last_queried_page = response.page_number
            # update the total pages
            total_pages = response.last_page
            # increment the page number
            puts "Last queried page: #{last_queried_page}"
            puts "Total pages: #{total_pages}"
        rescue => exception
            warn "Error on page #{page_number}"
            warn exception
            warn exception.backtrace
            next
        end
    end
end

def details_from_commit_response(commit_response)
    # get the commit sha
    commit_sha = commit_response['sha']
    commit_node_id = commit_response['node_id']
    # how many comments were made on the commit
    commit_comment_count = commit_response.dig('commit','comment_count')

    # get the committer & author login
    commit_author_login = commit_response.dig('author','login')
    commit_commiter_login = commit_response.dig('committer','login')

    # get the author node id
    commit_author_node_id = commit_response.dig('author','node_id')
    commit_commiter_node_id = commit_response.dig('committer','node_id')
    
    # get the author & committer url
    commit_author_url = commit_response.dig('author','url')
    commit_commiter_url = commit_response.dig('committer','url')

    # get the author & committer type and site admin status
    commit_author_type = commit_response.dig('author','type')
    commit_author_site_admin = commit_response.dig('author','site_admin')
    commit_commiter_type = commit_response.dig('committer','type')
    commit_commiter_site_admin = commit_response.dig('committer','site_admin')

    # get the first 256 characters of commit message
    commit_message = commit_response.dig('commit','message')[0..255]

    # get the commit verification
    commit_verification = commit_response.dig('commit','verification','verified')
    commit_verification_reason = commit_response.dig('commit','verification','reason')
    commit_verification_signature = commit_response.dig('commit','verification','signature')
    # get the commit status
    commit_status = commit_response['commit']['status']

    # return it all
    [
        commit_sha  ,
        commit_node_id  ,
        commit_comment_count  ,
        commit_author_login  ,
        commit_commiter_login  ,
        commit_author_node_id  ,
        commit_commiter_node_id  ,
        commit_author_url  ,
        commit_commiter_url  ,
        commit_author_type  ,
        commit_author_site_admin  ,
        commit_commiter_type  ,
        commit_commiter_site_admin  ,
        commit_message  ,
        commit_verification  ,
        commit_verification_reason  ,
        commit_verification_signature  ,
        commit_status
    ]

end

# Run the commit script
export_commit_author_and_status_to_csv