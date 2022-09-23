require 'fastlane_core/ui/ui'
require 'fastlane/action'
require 'fastlane/actions/slack'
require 'faraday'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class SlackMessageHelper
      @client = Faraday.new do |builder|
        builder.use(Faraday::Response::RaiseError)
      end

      def self.post_message(slack_url:, channel:, thread_timestamp:, username:, attachments:, link_names:, icon_url:, fail_on_error:)
        @client.post(slack_url) do |request|
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
      rescue StandardError => e
        UI.error("Error while pushing Slack message: #{e}")
        message = "Maybe the integration has no permission to post on this channel? Try removing the channel parameter in your Fastfile, this is usually caused by a misspelled or changed group/channel name or an expired SLACK_URL"
        if fail_on_error
          UI.user_error!(message)
        else
          UI.error(message)
        end
      end

      def self.prepare_message(options)
        options[:message] = trim(options[:message])
        options[:message] = convert_links(options[:message])
        options[:pretext] = newline_interpretation(options[:pretext])

        Fastlane::Actions::SlackAction.generate_slack_attachments(options)
      end

      def self.trim(text)
        Fastlane::Actions::SlackAction.trim_message(text || '')
      end

      def self.convert_links(text)
        Fastlane::Notification::Slack::LinkConverter.convert(text)
      end

      def self.newline_interpretation(text)
        (text || '').gsub('\n', "\n")
      end

      def self.format_channel(channel_name)
        if channel_name.nil? || channel_name.empty?
          nil
        elsif %w[# @].include?(channel_name[0])
          channel_name
        else
          '#' + channel_name
        end
      end
    end
  end
end
