module Voicemail
  class IntroMessageCreator

    begin
      require 'ahnsay'
    rescue LoadError
    end

    attr_accessor :current_message

    def initialize(message)
      raise ArgumentError, "MailboxPlayMessageIntroController needs a valid message passed to it" unless message
      @current_message = message
    end

    def intro_message
      Array(time_message) + Array(from_message)
    end

    def time_message
      case config.numeric_method
      when :i18n_string
        t 'voicemail.messages.message_received_on_x', received_on: I18n.localize(current_message[:received])
      when :play_numeric
        [t('voicemail.messages.message_received_on'), time_ssml]
      when :ahn_say
        [
          t('voicemail.messages.message_received_on'),
          Ahnsay.sounds_for_time(current_message[:received], format: config.datetime_format)
        ]
      end
    end

    def from_message
      case config.numeric_method
      when :i18n_string
        t 'voicemail.messages.message_received_from_x', from: from_string
      when :play_numeric
        [t('from'), from_ssml]
      when :ahn_say
        [t('from'), Ahnsay.sounds_for_digits(from_digits)]
      end
    end

private

    def t(key, opts = {})
      locale = opts[:locale] || I18n.default_locale
      opts   = { default: '', locale: locale }.merge(opts)
      prompt = I18n.t "#{key}.audio", opts
      text   = I18n.t "#{key}.text", opts

      prompt = "#{Adhearsion.config.i18n.audio_path}/#{locale}/#{prompt}" unless prompt.empty?

      RubySpeech::SSML.draw language: locale do
        if prompt.empty?
          string text
        else
          audio(src: prompt) { string text }
        end
      end
    end

    def from_digits
      current_message[:from].scan(/\d/).join
    end

    def from_string
      "".tap do |string|
        from_digits.each_char do |char|
          digit_word = I18n.t "digits.#{char}.text"
          if digit_word =~ /missing/
            string << char
          else
            string << digit_word
          end
        end
      end
    end

    def time_ssml
      output_formatter.ssml_for_time current_message[:received], format: config.datetime_format
    end

    def from_ssml
      if from_digits != ""
        output_formatter.ssml_for_characters from_digits
      else
        "unknown caller"
      end
    end

    def output_formatter
      @output_formatter ||= Adhearsion::CallController::Output::Formatter.new
    end

    def config
      Voicemail::Plugin.config
    end
  end
end
