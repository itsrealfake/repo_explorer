#!/usr/bin/env ruby

# This script will read every JSON file in the specified directory, process the commit data,
# and print out the total number of commits per year and contributor.
#
# Usage:
# ruby process_every_json.rb <json_directory_path>
#
# Example:
# ruby process_every_json.rb all_core_repo_commits_2023_12_08/commits_in_json

require 'pry'
require 'json'
require 'date'

json_dir_path = ARGV[0]

all_commits = []

# Class representing a commit entry with relevant data extracted.
# {
#   2023: {
#       committer: cumulative commits
#   }
# }
#
commits_per_year = Hash.new(0)


class CommitEntry
  attr_reader :sha, :committed_date, :author_date, :data, :author_login, :committer_login

  # Initializes the CommitEntry with commit data.
  # @param data [Hash] The raw commit data
  def initialize(data)
    @data = data
    @sha = data['sha']
    parse_dates
    get_logins
  end

  private

  # Extracts the login information for the author and committer.
  def get_logins
    @author_login = data.dig('author', 'login')
    @committer_login = data.dig('committer', 'login')
  end

  # Parses the author and committer dates from the commit data.
  def parse_dates
    author_date_str = data.dig('commit', 'author', 'date')
    committed_date_str = data.dig('commit', 'committer', 'date')

    @author_date = parse_date(author_date_str)
    @committed_date = parse_date(committed_date_str)
  end

  # Parses a date string into a Date object.
  # @param date_str [String] The date string to parse
  # @return [Date] The parsed date
  def parse_date(date_str)
    Date.parse(date_str)
  end
end

# Open every JSON file from the specified directory (original scraped data) and create a new CommitEntry from each commit.
Dir.each_child(json_dir_path) do |entry_name|
  next if entry_name.include?('headers')
  file = File.open("#{json_dir_path}/#{entry_name}")
  contents = file.read
  data = JSON.parse(contents)

  data.each do |commit|
    all_commits << CommitEntry.new(commit)
  end
end

# Class to breakdown and summarize commit data.
class CommitsBreakdown
  attr_reader :hash_of_all_years, :total_commits_for_all_years

  # Initializes the CommitsBreakdown with all commits and processes the data.
  # @param all_commits [Array<CommitEntry>] The list of all commit entries
  def initialize(all_commits)
    @all_commits = all_commits
    @hash_of_all_years = Hash.new
    process_all_commits
    sum_all_commits
  end

  private

  # Sums up the total commits for all years.
  def sum_all_commits
    total_commits_for_all_years = 0
    hash_of_all_years.each do |key, value|
      puts key
        commits_for_this_year =  hash_of_all_years[key]['total_commits_this_year']
      total_commits_for_all_years += commits_for_this_year
    end
    @total_commits_for_all_years = total_commits_for_all_years
  end
  def yearly_commits_by_author_hash
    @yearly_commits_by_author_hash ||=  Hash.new(0)
  end

  # Processes all commits to count the number of commits per year and author.
  def process_all_commits
    @all_commits.each do |commit|
      year = commit.committed_date.year
      author = commit.author_login
      create_hash_for_new_year_if_none_exists(year)
      count_commit(year, author)
    end
  end

  # Creates a hash for a new year if it doesn't exist already.
  # @param year [Integer] The year to create a hash for
  def create_hash_for_new_year_if_none_exists(year)
    # create a new year if the year doesn't exist already
    puts "creating a new hash for #{year}" unless hash_of_all_years[year]
    hash_of_all_years[year] ||= Hash.new(0)
    hash_of_all_years[year]["total_commits_this_year"] ||= 0
  end

  # Counts a commit for a specific year and author.
  # @param commit_year [Integer] The year of the commit
  # @param commit_author [String] The author of the commit
  def count_commit(commit_year, commit_author)
    hash_of_all_years[commit_year][commit_author] += 1
    hash_of_all_years[commit_year]['total_commits_this_year'] += 1
    puts "#{commit_author} has #{hash_of_all_years[commit_year][commit_author] } commits for #{commit_year}"
  end
end

# Process and summarize the commit data.
breakdown = CommitsBreakdown.new(all_commits)

# Output the total commits.
puts "Total commits: #{breakdown.total_commits_for_all_years}"

# Output the commits per year.
breakdown.hash_of_all_years.each do |key, value|
  puts "#{key} had #{value['total_commits_this_year']} commits"
end

binding.pry
