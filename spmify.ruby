#!/usr/bin/env ruby

require "json"
require "net/http"

# User-defined
INPUT_PODFILE_LOCK_FILEPATH = "Podfile.lock"
OUTPUT_PACKAGE_SWIFT_FILEPATH = "Package.swift"

# Constants
PODFILE_LOCK_DEPENDENCIES_DELIMETER = "DEPENDENCIES"

def extract_explicitly_declared_pods_with_semantic_version_rules
  output = []
  read_line = false
  File.foreach(INPUT_PODFILE_LOCK_FILEPATH) do |line|
    if line.include?(PODFILE_LOCK_DEPENDENCIES_DELIMETER)
      read_line = true
    elsif read_line
      output << line.strip if line.start_with?("  -")
    end
  end
  output
end

def extract_all_pods_with_specific_versions
  output = []
  File.foreach(INPUT_PODFILE_LOCK_FILEPATH) do |line|
    break if line.include?(PODFILE_LOCK_DEPENDENCIES_DELIMETER)
    output << line.strip if line.start_with?("  -")
  end
  output
end

def match_dependencies(all_pods_with_specific_versions, explicitly_declared_pods_with_semantic_version_rules)
  all_dependencies = all_pods_with_specific_versions.flat_map { |line| line.scan(/- (.*?)(?:\s|$)/) }.flatten
  explicit_dependencies = explicitly_declared_pods_with_semantic_version_rules.each_with_object({}) do |line, hash|
    if (match = line.match(/- (.*?)(?:\s|$)\((.*?)\)/))
      dependency, version = match.captures
      hash[dependency] = version
    end
  end
  # Match dependencies and versions
  output = all_dependencies.map do |dependency|
    version = explicit_dependencies[dependency]
    "- #{dependency}#{version ? " (#{version})" : ""}"
  end

  output.sort_by { |line| line.downcase } # Make sort case insensitive, because Ruby's default sort is case sensitive
end

def convert_internal_pod_dependency_into_packages(internal_pod)
  match_data = internal_pod.match(/- "(.+) \(from `([^`]+)`, (branch|tag) `([^`]+)`/)
  return "" unless match_data
  name = match_data[1]
  url = match_data[2].gsub("git@github.com:", "https://github.com/")
  unless url.end_with?(".git")
    url << ".git"
  end
  is_branch = match_data[3] == "branch"
  branch_or_version = match_data[4]
  if is_branch
    supports_spm = repository_contains_package_swift?(url, branch_or_version)
  else
    supports_spm = repository_contains_package_swift?(url)
  end
  {
    name: name,
    url: url,
    branch_or_version: branch_or_version,
    is_branch: is_branch,
    supports_spm: supports_spm,
  }
end

def get_pod_git_url(pod_name)
  begin
    spec_output = `pod spec cat #{pod_name}`
    spec_json = JSON.parse(spec_output)
    git_url = spec_json['source']['git']
    git_url
  rescue JSON::ParserError => e
    puts("❌ Error when fetching Pod URL for pod #{pod_name}: Invalid JSON format - #{e.message.gsub("\n", "")}. If this is a Development Pod, or a pod with sub-directory, this is not supported by this script.")
    nil
  end
end

def repository_contains_package_swift?(repository_url, branch = nil, is_redirect = false)
  # Extract owner and repository name from the URL
  # Accepts URLs in the formats:
  # - https://github.com/org/repo
  # - https://github.com/org/repo.git
  match = repository_url.match(/github.com\/([^\/]+)\/([^\.\/]+)\/?(?:\.git)?$/)
  unless match || is_redirect
    puts("❌ URL #{repository_url} didn't match expected GitHub URL format.")
    return false
  end

  owner = match[1] unless is_redirect
  repo = match[2] unless is_redirect

  # Make a GET request to GitHub API to retrieve repository contents
  url = is_redirect ? repository_url : "https://api.github.com/repos/#{owner}/#{repo}/contents"
  if branch && !is_redirect
    url << "?ref=#{branch}"
  end
  uri = URI(url)
  response = Net::HTTP.get_response(uri)

  # Check if the request was successful.
  unless response.is_a?(Net::HTTPSuccess)
    # Check if the URL has been moved. Happens when GitHub users change their usernames, or organization name.
    if response.is_a?(Net::HTTPMovedPermanently)
      redirected_url = response["location"]
      puts "🛤️  The repo URL #{repository_url} was permanently moved to #{redirected_url}, so we're checking that one instead."
      return repository_contains_package_swift?(redirected_url, branch, true)
    elsif response.is_a?(Net::HTTPNotFound)
      puts("⚠️  Repository not found. The repo URL #{repository_url} might be a private repositories. This script doesn't use any authentication methods.")
      return false
    else
      puts("❌ API request to GitHub failed. Repo URL: #{repository_url}. Response body: #{response.body}")
      return false
    end
  end

  # Parse the response JSON
  data = JSON.parse(response.body)

  # Check if the "Package.swift" file exists in the repository
  data.any? { |file| file["path"] == "Package.swift" }
end

def extract_pod_data(pods_with_versions)
  pods_with_versions.map do |pod_with_version|
    match_data = pod_with_version.match(/- (.+) \((.+)\)/)
    return nil unless match_data
    name = match_data[1]
    version = match_data[2]
    url = get_pod_git_url(name)
    supports_spm = url ? repository_contains_package_swift?(url) : false
    {
      name: name,
      url: url,
      branch_or_version: version,
      is_branch: false,
      supports_spm: supports_spm,
    }
  end.compact
end

# Check Podfile
unless File.file?(INPUT_PODFILE_LOCK_FILEPATH)
  puts("❌ Cannot find any podfile named \"#{POINPUT_PODFILE_LOCK_FILEPATHDFILE}\"")
  exit
end

all_explicitly_declared_pods_with_semantic_version_rules = extract_explicitly_declared_pods_with_semantic_version_rules
external_pods_with_semantic_version_rules = all_explicitly_declared_pods_with_semantic_version_rules.filter { |pod| !pod.start_with?("- \"") }
internal_pods_with_semantic_version_rules = all_explicitly_declared_pods_with_semantic_version_rules.filter { |pod| pod.start_with?("- \"") }

matched_dependencies = match_dependencies(external_pods_with_semantic_version_rules, extract_all_pods_with_specific_versions)
internal_pods_data = internal_pods_with_semantic_version_rules.map { |line| convert_internal_pod_dependency_into_packages(line) }

pods_data = extract_pod_data(matched_dependencies) + internal_pods_data

package_dependencies = pods_data.map do |data|
  reference = data[:is_branch] ? ".branch(\"#{data[:branch_or_version]}\")" : ".upToNextMajor(from: \"#{data[:branch_or_version]}\")"
  if data[:supports_spm]
    ".package(name: \"#{data[:name]}\", url: \"#{data[:url] || "TO-DO: Resolve this dependency manually"}\", #{reference}),\n"
  else
    "// .package(name: \"#{data[:name]}\", url: \"#{data[:url] || "TO-DO: Not repo URL could be found for this identifier"}\", #{reference}), // TODO: This dependency doesn't support SPM yet (its repo doesn't have a Package.swift, or the repo couldn't be accessed)\n"
  end
end.sort_by! { |line| line.downcase } # Make sort case insensitive, because Ruby's default sort is case sensitive

# Generate Package.swift content
package_swift_content = <<-SWIFT
// swift-tools-version:5.5

import PackageDescription

// When adding dependencies, add them to this array
let packageDependencies: [Package.Dependency] = [
SWIFT

# Process external dependencies
package_dependencies.each do |dependency|
  package_swift_content += "    #{dependency}"
end

package_swift_content += <<-SWIFT
]

let package = Package(
  name: "YourPackageName",
  platforms: [
      .macOS(.v11),
      .iOS(.v14),
  ],
  products: [
      .library(name: "YourPackageName", targets: ["YourTargetName"]),
  ],
  dependencies: packageDependencies,
  targets: [
      .target(
          name: "YourTargetName",
          dependencies: packageDependencies.map { Target.Dependency(stringLiteral: $0.name!) },
          path: "Sources"
      ),
  ]
)
SWIFT

File.write(OUTPUT_PACKAGE_SWIFT_FILEPATH, package_swift_content)
