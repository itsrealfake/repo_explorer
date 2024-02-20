# The script will accept a repo name, an API token, and the name of the output file. 
# 
# The script will first request all the commits from the repo for a date range
# 
# Usage:
# ruby list_github_commits.rb <github_repo_name> <github_api_token> <output_file_name>
# 
# Example:
# ruby list_github_commits.rb "rails/rails" "1234567890abcdefg" "rails_mergers.csv"
#
# TODO: 
#   - pagination
#   - what else?



require 'json'
require 'net/http'
require 'uri'
require 'csv'
require 'pry'


# Date Range
one_year_ago = (Date.today - 365).iso8601 
today = (Date.today).iso8601

# Get the repo name, github api token, and output file name
repo_name = ARGV[0]
github_api_token = ARGV[1]
output_file_name = ARGV[2]

raise "Please provide a repo name" unless repo_name
raise "Please provide a github api token" unless github_api_token
raise "Please provide an output file name" unless output_file_name

# Get the list of commits to the repo
uri = URI.parse("https://api.github.com/repos/#{repo_name}/commits?since=#{one_year_ago}&until=#{today}&per_page=100")
request = Net::HTTP::Get.new(uri)
request["Authorization"] = "token #{github_api_token}"
request["Accept"] = "application/vnd.github.v3+json"
request["User-Agent"] = "Ruby"
req_options = { use_ssl: uri.scheme == "https" }
response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
	http.request(request)
end
github_commits_response = JSON.parse(response.body)

# List total number of commits per contributor for the dates in question
commits_by_contributor = Hash.new(0)
contributor_node_ids = Hash.new(0)
github_commits_response.each do |commit|
    # binding.pry
	begin
		# Try to iterate the value and catch any error thrown if the author is nil
		# If the author is nil, skip it
		commits_by_contributor[commit['author']['login']] += 1 

		# binding.pry
		contributor_node_ids[commit['author']['login']] = commit['author']['node_id']

	rescue
		next
	end
end



# Output the contributor name and number of pull requests merged
CSV.open(output_file_name, "a+") do |csv|
	total_percent = 0
	commits_by_contributor.each do |contributor, commits|
		# the percentage of total commits
		percentage_of_total_commits = (commits.to_f / commits_by_contributor.values.sum.to_f * 100.0).round(2)
		total_percent += percentage_of_total_commits
		csv << [contributor, ' ' ,commits,  " #{percentage_of_total_commits}%"]
	end
	csv << [ 'Total %', total_percent, 'Total Commits', commits_by_contributor.values.sum.to_f]
end

# Output the contributor name and node id to a new file
CSV.open('contributor_node_ids.csv', "a+") do |csv|
	contributor_node_ids.each do |contributor, node_id|
		csv << [contributor, node_id]
	end
end


# Find the issues that are pull requests for the repo in the time range
uri = URI.parse("https://api.github.com/repos/#{repo_name}/issues?since=#{one_year_ago}&until=#{today}&per_page=100")
request = Net::HTTP::Get.new(uri)
request["Authorization"] = "token #{github_api_token}"
request["Accept"] = "application/vnd.github.v3+json"
request["User-Agent"] = "Ruby"
req_options = { use_ssl: uri.scheme == "https" }
response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
	http.request(request)
end
github_issues_response = JSON.parse(response.body)

# List total number of pull requests per contributor for the dates in question
pull_requests_by_contributor = Hash.new(0)
github_issues_response.each do |issue|
	pull_requests_by_contributor[issue['user']['login']] += 1 if issue['pull_request']
end

# Output the contributor name and number of pull requests merged
CSV.open(output_file_name, "a+") do |csv|
	total_percent = 0
	pull_requests_by_contributor.each do |contributor, pull_requests|
		# the percentage of total pull requests
		percentage_of_total_pull_requests = (pull_requests.to_f / pull_requests_by_contributor.values.sum.to_f * 100.0).round(2)
		total_percent += percentage_of_total_pull_requests
		csv << [contributor, ' ' ,pull_requests,  " #{percentage_of_total_pull_requests}%"]
	end
	csv << [ 'Total %', total_percent, 'Total Pull Requests', pull_requests_by_contributor.values.sum.to_f]
end

# a function to find all the pull requests for the repo within the time frame
def find_pull_requests(repo_name, github_api_token, since_date, until_date)
	uri = URI.parse("https://api.github.com/repos/#{repo_name}/pulls?since=#{since_date}&until=#{until_date}&per_page=100")
	request = Net::HTTP::Get.new(uri)
	request["Authorization"] = "token #{github_api_token}"
	request["Accept"] = "application/vnd.github.v3+json"
	request["User-Agent"] = "Ruby"
	req_options = { use_ssl: uri.scheme == "https" }
	response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
		http.request(request)
	end
	github_pull_requests_response = JSON.parse(response.body)
	return github_pull_requests_response
end

# a function that finds the author, and status of a pull request from an api response
def find_pull_request_author_and_status(pull_request)
	author = pull_request['user']['login']
	status = pull_request['state']
	return author, status
end

# a wrapper function and exports the pull request author & status to a csv
def export_pull_request_author_and_status_to_csv(repo_name, github_api_token, since_date, until_date, output_file_name)
	pull_requests = find_pull_requests(repo_name, github_api_token, since_date, until_date)
	CSV.open(output_file_name, "a+") do |csv|
		pull_requests.each do |pull_request|
			author, status = find_pull_request_author_and_status(pull_request)
			csv << [author, status]
		end
	end
end	
