#!/usr/bin/env ruby

# This script will read every JSON file in the specified directory and provide a CSV file with commit data.
#
# Usage:
# ruby process_commit_data.rb <json_directory_path> <output_file_name>
#
# Example:
# ruby process_commit_data.rb all_core_repo_commits_2023_12_08/commits_in_json all_commit_re-process_Mar_26_dingo.csv

# this script will read every json file in the directory and provide a CSV file
require 'json'
require 'date'
require 'pry'
require 'csv'

# Class for handling the arguments passed to the script.
class Arguments
  attr_reader :repo_name, :output_file_name, :page_number, :github_api_token
  def initialize
    @output_file_name = ARGV[1]
    check_for_all_arguments
    print_execution_message
  end

  private

  # Checks if all required arguments are provided.
  def check_for_all_arguments
    raise ArgumentError.new("Please provide an output file name") unless output_file_name
  end

  # Prints a message indicating the script's action.
  def print_execution_message
    puts "Searching for pull requests on #{@repo_name} and saving to #{@output_file_name}"
  end
end

# Class to handle CSV file operations.
class CsvHandler
  attr_reader :csv_name

  def initialize(csv_name, headers)
    @csv_name = csv_name
    @headers = headers
    check_or_create_file
  end

  # Adds a row to the CSV file.
  def add_row_to_csv(row)
    CSV.open(@csv_name, "a+") do |csv|
      csv << row
    end
  end

  private

  # Checks if the CSV file exists, creates it if not, and initializes headers.
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

  # Prints a message indicating the creation of the CSV file.
  def print_creation_message
    puts "Created file #{@csv_name}"
  end

  # Initializes the headers of the CSV file.
  def initialize_csv_headers
      puts "initializing csv headers: #{@headers}"
    CSV.open(@csv_name, "a+") do |csv|
      csv << [*@headers]
    end
  end
end

# Extracts the entire commit message from the commit response.
def entire_commit_message(commit_response)
  commit_response.dig('commit', 'message')
end

# Determines if a commit may be a self-merge commit.
# TODO figure out if this is a self_merge commit
def may_be_self_merge(commit_response, is_merge_commit)
    #  if this is not a merge commit, then return false
    return is_merge_commit if is_merge_commit == false
    commit_message = entire_commit_message(commit_response)
    # later, we might want to calculate a percentage value based on the number of commits in the PR, and how many
    # of them are authored by the maintainer who ran the merge script.
    could_be_self_merge = false
    
    author_of_commit_message = get_author_login(commit_response)

    # if the commit message includes the author's login, then it is a self merge
    could_be_self_merge = commit_message.downcase.include?(author_of_commit_message.downcase)
    could_be_self_merge && is_merge_commit
end

# This method returns true if the commit author's login is included in a merge commit message
def same_maintainer_login_included_in_commit_message(commit_response)
    author_login = get_author_login(commit_response)
    # get the commit message
    commit_message = entire_commit_message(commit_response)
    # check if the author's login is in the commit message
    return false if author_login.nil?
    commit_message.downcase.include?(author_login.downcase)
end

# This method returns the PGP key used to sign the commit
def get_pgp_key_used_in_commit_verification_signature(commit_response)
    # get the pgp signature from the commit response
    # process the signature to find the key used to create it
    # return the key
    "TODO IMPLEMENT ME"
end

# This method returns true if the committer was a maintainer on the date of the commit
# and false otherwise
def committer_was_maintainer_on_commit_date(commit_response)
    # get the committer's PGP key
    pgp_key_used = get_pgp_key_used_in_commit_verification_signature(commit_response)

    # get the date of the commit

    # use the date to find a list of PGP keys for maintainers on that date

    # if the committer's PGP key is in the list of maintainers, return true
    # else return false
    "unknown"
end

def get_author_login(commit_response)
    if commit_response.dig('author').nil?
        commit_author_login = commit_response.dig('commit','author','name')
    else 
        commit_author_login = commit_response.dig('author','login')
    end
    commit_author_login
end

def get_committer_login(commit_response)
    if commit_response.dig('committer').nil?
        commit_committer_login = commit_response.dig('commit','committer','name')
    else 
        commit_committer_login = commit_response.dig('committer','login')
    end
    commit_committer_login
end

def details_from_commit_response(commit_response)
  # get the commit sha
  commit_sha = commit_response['sha']

  commit_node_id = commit_response['node_id']
  # how many comments were made on the commit
  commit_comment_count = commit_response.dig('commit','comment_count')

  # get the committer & author login
  commit_committer_login = get_committer_login(commit_response)
  

  commit_author_login = get_author_login(commit_response)

  # get the author node id
  commit_author_node_id = commit_response.dig('author','node_id')
  commit_committer_node_id = commit_response.dig('committer','node_id')
  
  # get the author & committer url
  commit_author_url = commit_response.dig('author','url')
  commit_committer_url = commit_response.dig('committer','url')

  # get the author and committer date values
  commit_author_date = commit_response.dig('commit', 'author','date')
  commit_committer_date = commit_response.dig('commit', 'committer','date')


  # get the author & committer type and site admin status
  commit_author_type = commit_response.dig('author','type')
  commit_author_site_admin = commit_response.dig('author','site_admin')
  commit_committer_type = commit_response.dig('committer','type')
  commit_committer_site_admin = commit_response.dig('committer','site_admin')

  # get the first 256 characters of commit message
  commit_message = entire_commit_message(commit_response)[0..255]

  # is merge commit?
  is_merge_commit = commit_message.downcase.include?('acks for top commit') || commit_message.downcase.start_with?('merge bitcoin')
  
  may_be_self_merge = may_be_self_merge(commit_response, is_merge_commit)

  # get the commit verification
  commit_verification = commit_response.dig('commit','verification','verified')
  commit_verification_reason = commit_response.dig('commit','verification','reason')
  commit_verification_signature = commit_response.dig('commit','verification','signature')
  # get the commit status
  commit_status = commit_response['commit']['status']

  # was the committer a maintainer on the date of the commit?
  committer_was_maintainer = committer_was_maintainer_on_commit_date(commit_response)

  # if the commit is a merge commit, then check if the author's username is included in the commit message
  merge_author_login_included_in_commit_message = is_merge_commit && same_maintainer_login_included_in_commit_message(commit_response)

  # return it all
  [
      commit_sha  ,
      commit_node_id  ,
      commit_comment_count  ,
      commit_author_login  ,
      commit_committer_login  ,
      commit_author_node_id  ,
      commit_committer_node_id  ,
      commit_author_url  ,
      commit_committer_url  ,
      commit_committer_date,
      commit_author_date,
      commit_author_type  ,
      commit_author_site_admin  ,
      commit_committer_type  ,
      commit_committer_site_admin  ,
      commit_message  ,
      commit_verification  ,
      commit_verification_reason  ,
      commit_verification_signature  ,
      commit_status,
      is_merge_commit,
      may_be_self_merge,
      committer_was_maintainer,
      merge_author_login_included_in_commit_message # this is duplicative, :(
  ]

end



# set arguments from the command line
args = Arguments.new
json_dir_path = ARGV[0]
output_file_name = args.output_file_name

# Create a CSV file and add the headers.
commits_csv_headers = [
    'commit_sha'  ,
    'commit_node_id'  ,
    'commit_comment_count'  ,
    'commit_author_login'  ,
    'commit_committer_login'  ,
    'commit_author_node_id'  ,
    'commit_committer_node_id'  ,
    'commit_author_url'  ,
    'commit_committer_url'  ,
    'commit_committer_date',
    'commit_author_date',
    'commit_author_type'  ,
    'commit_author_site_admin'  ,
    'commit_committer_type'  ,
    'commit_committer_site_admin'  ,
    'commit_message'  ,
    'commit_verification'  ,
    'commit_verification_reason'  ,
    'commit_verification_signature'  ,
    'commit_status',
    'is_merge_commit',
    'may_be_self_merge',
    'committer_was_maintainer',
    'merge_author_login_included_in_commit_message'
]

csv = CsvHandler.new(output_file_name, commits_csv_headers)

# Open every JSON file from the original scraped data
# create a new entry from each commit
Dir.each_child(json_dir_path) do |entry_name|
  next if entry_name.include?('headers')
  file = File.open("#{json_dir_path}/#{entry_name}")
  contents = file.read
  data = JSON.parse(contents)

  data.each do |commit_response|
    csv.add_row_to_csv(details_from_commit_response(commit_response))
  end
end
