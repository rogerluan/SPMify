#!/usr/bin/env ruby

require "json"

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
  branch_or_version_strategy = match_data[3] == "branch" ? ".branch(" : ".upToNextMajor(from: ,"
  branch_or_version = match_data[4]
  ".package(name: \"#{name}\", url: \"#{url}\", #{branch_or_version_strategy}\"#{branch_or_version}\")),\n"
end

def get_pod_git_url(pod_name)
  begin
    spec_output = `pod spec cat #{pod_name}`
    spec_json = JSON.parse(spec_output)
    git_url = spec_json['source']['git']
    git_url
  rescue JSON::ParserError => e
    puts "Error when fetching Pod URL for pod #{pod_name}: Invalid JSON format - #{e.message}"
    nil
  end
end

def extract_pod_data(pods_with_versions)
  pods_with_versions.map do |pod_with_version|
    match_data = pod_with_version.match(/- (.+) \((.+)\)/)
    return nil unless match_data
    name = match_data[1]
    version = match_data[2]
    {
      name: name,
      url: get_pod_git_url(name),
      version: version,
    }
  end.compact
end

# Check Podfile
unless File.file?(INPUT_PODFILE_LOCK_FILEPATH)
  puts "Cannot find any podfile named \"#{POINPUT_PODFILE_LOCK_FILEPATHDFILE}\""
  exit
end

all_explicitly_declared_pods_with_semantic_version_rules = extract_explicitly_declared_pods_with_semantic_version_rules
external_pods_with_semantic_version_rules = all_explicitly_declared_pods_with_semantic_version_rules.filter { |pod| !pod.start_with?("- \"") }
internal_pods_with_semantic_version_rules = all_explicitly_declared_pods_with_semantic_version_rules.filter { |pod| pod.start_with?("- \"") }

matched_dependencies = match_dependencies(external_pods_with_semantic_version_rules, extract_all_pods_with_specific_versions)
internal_packages = internal_pods_with_semantic_version_rules.map { |line| convert_internal_pod_dependency_into_packages(line) }

pods_data = extract_pod_data(matched_dependencies)

package_dependencies = []
pods_data.each do |data|
  package_dependencies << ".package(name: \"#{data[:name]}\", url: \"#{data[:url] || "TO-DO: Resolve this dependency manually"}\", .upToNextMajor(from: \"#{data[:version]}\")),\n"
end
package_dependencies = package_dependencies + internal_packages
package_dependencies.sort_by! { |line| line.downcase } # Make sort case insensitive, because Ruby's default sort is case sensitive

# Generate Package.swift content
package_swift_content = <<-SWIFT
// swift-tools-version:5.8

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
