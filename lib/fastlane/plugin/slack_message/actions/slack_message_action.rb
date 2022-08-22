require 'fastlane/action'
require 'fastlane/actions/slack'
require_relative '../helper/slack_message_helper'

module Fastlane
  module Actions
    class SlackMessageAction < Action
      class Runner
        def initialize(slack_url)
          @webhook_url = slack_url

          @client = Faraday.new do |conn|
            conn.use(Faraday::Response::RaiseError)
          end
        end

        def run(options)

          options[:message] = Fastlane::Actions::SlackAction.trim_message(options[:message].to_s || '')
          options[:message] = Fastlane::Notification::Slack::LinkConverter.convert(options[:message])

          options[:pretext] = options[:pretext].gsub('\n', "\n") unless options[:pretext].nil?

          channel = nil
          if options[:channel].to_s.length > 0
            channel = options[:channel]
            channel = ('#' + options[:channel]) unless ['#', '@'].include?(channel[0]) # send message to channel by default
          end

          username = options[:use_webhook_configured_username_and_icon] ? nil : options[:username]

          slack_attachment = Fastlane::Actions::SlackAction.generate_slack_attachments(options)
          link_names = options[:link_names]
          icon_url = options[:use_webhook_configured_username_and_icon] ? nil : options[:icon_url]

          post_message(
            channel: channel,
            thread_timestamp: options[:thread_timestamp],
            username: username,
            attachments: [slack_attachment],
            link_names: link_names,
            icon_url: icon_url,
            fail_on_error: options[:fail_on_error]
          )
        end

        def post_message(channel:, thread_timestamp:, username:, attachments:, link_names:, icon_url:, fail_on_error:)
          @client.post(@webhook_url) do |request|
            request.headers['Content-Type'] = 'application/json'
            request.body = {
              channel: channel,
              username: username,
              thread_ts: thread_timestamp,
              icon_url: icon_url,
              attachments: attachments,
              link_names: link_names
            }.to_json
          end
          UI.success('Successfully sent Slack notification')
        rescue => error
          UI.error("Exception: #{error}")
          message = "Error pushing Slack message, maybe the integration has no permission to post on this channel? Try removing the channel parameter in your Fastfile, this is usually caused by a misspelled or changed group/channel name or an expired SLACK_URL"
          if fail_on_error
            UI.user_error!(message)
          else
            UI.error(message)
          end
        end
      end

      def self.run(options)
        Runner.new(options[:slack_url]).run(options)
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :message,
                                       env_name: "FL_SLACK_MESSAGE",
                                       description: "The message that should be displayed on Slack. This supports the standard Slack markup language",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :pretext,
                                       env_name: "FL_SLACK_PRETEXT",
                                       description: "This is optional text that appears above the message attachment block. This supports the standard Slack markup language",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :channel,
                                       env_name: "FL_SLACK_CHANNEL",
                                       description: "#channel or @username",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :thread_timestamp,
                                       env_name: "FL_SLACK_THREAD_TIMESTAMP",
                                       description: "Timestamp of the message to reply",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :slack_url,
                                       env_name: "SLACK_URL",
                                       sensitive: true,
                                       description: "Create an Incoming WebHook for your Slack group",
                                       verify_block: proc do |value|
                                         UI.user_error!("Invalid URL, must start with https://") unless value.start_with?("https://")
                                       end),
          FastlaneCore::ConfigItem.new(key: :username,
                                       env_name: "FL_SLACK_USERNAME",
                                       description: "Overrides the webhook's username property if use_webhook_configured_username_and_icon is false",
                                       default_value: "fastlane",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :use_webhook_configured_username_and_icon,
                                       env_name: "FL_SLACK_USE_WEBHOOK_CONFIGURED_USERNAME_AND_ICON",
                                       description: "Use webhook's default username and icon settings? (true/false)",
                                       default_value: false,
                                       type: Boolean,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :icon_url,
                                       env_name: "FL_SLACK_ICON_URL",
                                       description: "Overrides the webhook's image property if use_webhook_configured_username_and_icon is false",
                                       default_value: "https://fastlane.tools/assets/img/fastlane_icon.png",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :payload,
                                       env_name: "FL_SLACK_PAYLOAD",
                                       description: "Add additional information to this post. payload must be a hash containing any key with any value",
                                       default_value: {},
                                       type: Hash),
          FastlaneCore::ConfigItem.new(key: :default_payloads,
                                       env_name: "FL_SLACK_DEFAULT_PAYLOADS",
                                       description: "Specifies default payloads to include. Pass an empty array to suppress all the default payloads",
                                       default_value: ['lane', 'test_result', 'git_branch', 'git_author', 'last_git_commit', 'last_git_commit_hash'],
                                       type: Array),
          FastlaneCore::ConfigItem.new(key: :attachment_properties,
                                       env_name: "FL_SLACK_ATTACHMENT_PROPERTIES",
                                       description: "Merge additional properties in the slack attachment, see https://api.slack.com/docs/attachments",
                                       default_value: {},
                                       type: Hash),
          FastlaneCore::ConfigItem.new(key: :success,
                                       env_name: "FL_SLACK_SUCCESS",
                                       description: "Was this build successful? (true/false)",
                                       optional: true,
                                       default_value: true,
                                       type: Boolean),
          FastlaneCore::ConfigItem.new(key: :fail_on_error,
                                       env_name: "FL_SLACK_FAIL_ON_ERROR",
                                       description: "Should an error sending the slack notification cause a failure? (true/false)",
                                       optional: true,
                                       default_value: true,
                                       type: Boolean),
          FastlaneCore::ConfigItem.new(key: :link_names,
                                       env_name: "FL_SLACK_LINK_NAMES",
                                       description: "Find and link channel names and usernames (true/false)",
                                       optional: true,
                                       default_value: false,
                                       type: Boolean)
        ]
      end

      def self.is_supported?(platform)
        true
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.description
        "Send a message to your [Slack](https://slack.com) group"
      end

      def self.details
        "This plugin is forked from the Fastlane Slack action. Additionally, it takes thread_timestamp parameter to send the message under a thread."
      end

      def self.authors
        ["Doruk Kangal"]
      end

      def self.example_code
        [
          'slack(message: "App successfully released!")',
          'slack(
            message: "App successfully released!",
            channel: "#channel",  # Optional, by default will post to the default channel configured for the POST URL.
            success: true,        # Optional, defaults to true.
            payload: {            # Optional, lets you specify any number of your own Slack attachments.
              "Build Date" => Time.new.to_s,
              "Built by" => "Jenkins",
            },
            default_payloads: [:git_branch, :git_author], # Optional, lets you specify default payloads to include. Pass an empty array to suppress all the default payloads.
            attachment_properties: { # Optional, lets you specify any other properties available for attachments in the slack API (see https://api.slack.com/docs/attachments).
                                     # This hash is deep merged with the existing properties set using the other properties above. This allows your own fields properties to be appended to the existing fields that were created using the `payload` property for instance.
              thumb_url: "https://example.com/path/to/thumb.png",
              fields: [{
                title: "My Field",
                value: "My Value",
                short: true
              }]
            }
          )'
        ]
      end
    end
  end
end
