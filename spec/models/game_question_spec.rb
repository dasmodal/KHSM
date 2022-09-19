# (c) goodprogrammer.ru

require 'rails_helper'

# Тестовый сценарий для модели игрового вопроса,
# в идеале весь наш функционал (все методы) должны быть протестированы.
RSpec.describe GameQuestion, type: :model do

  # задаем локальную переменную game_question, доступную во всех тестах этого сценария
  # она будет создана на фабрике заново для каждого блока it, где она вызывается
  let(:game_question) { FactoryBot.create(:game_question, a: 2, b: 1, c: 4, d: 3) }

  # группа тестов на игровое состояние объекта вопроса
  context 'game status' do
    # тест на правильную генерацию хэша с вариантами
    it 'correct .variants' do
      expect(game_question.variants).to eq({'a' => game_question.question.answer2,
                                            'b' => game_question.question.answer1,
                                            'c' => game_question.question.answer4,
                                            'd' => game_question.question.answer3})
    end

    it 'correct .answer_correct?' do
      # именно под буквой b в тесте мы спрятали указатель на верный ответ
      expect(game_question.answer_correct?('b')).to be_truthy
    end
  end

  # help_hash у нас имеет такой формат:
  # {
  #   fifty_fifty: ['a', 'b'], # При использовании подсказски остались варианты a и b
  #   audience_help: {'a' => 42, 'c' => 37 ...}, # Распределение голосов по вариантам a, b, c, d
  #   friend_call: 'Василий Петрович считает, что правильный ответ A'
  # }
  #

  context 'user helpers' do
    it 'correct audience_help' do
      expect(game_question.help_hash).not_to include(:audience_help)

      game_question.add_audience_help

      expect(game_question.help_hash).to include(:audience_help)

      ah = game_question.help_hash[:audience_help]
      expect(ah.keys).to contain_exactly('a', 'b', 'c', 'd')
    end
  end

  it 'correct .level & .text delegates' do
    expect(game_question.level).to eq(game_question.question.level)
    expect(game_question.text).to eq(game_question.question.text)
  end

  it 'correct_answer_key' do
    expect(game_question.correct_answer_key).to eq('b')
  end

  describe '#add_friend_call' do
    let(:friend_call) { game_question.help_hash[:friend_call] }

    context 'before friend call use' do
      it 'help not to be' do
        expect(friend_call).not_to be
      end
    end

    context 'after friend call use' do
      before { game_question.add_friend_call }

      it 'help to be' do
        expect(friend_call).to be
      end

      it 'help is String' do
        expect(friend_call).to be_kind_of String
      end

      it 'help contains variant' do
        expect(friend_call[-1]).to be_between('A', 'D')
      end
    end
  end

  describe '#add_fifty_fifty' do
    let(:fifty_fifty) { game_question.help_hash[:fifty_fifty] }

    context 'before fifty fifty use' do
      it 'help not to be' do
        expect(fifty_fifty).not_to be
      end
    end

    context 'after fifty fifty use' do
      before { game_question.add_fifty_fifty }

      it 'help to be' do
        expect(fifty_fifty).to be
      end

      it 'help is Array' do
        expect(fifty_fifty).to be_kind_of Array
      end

      it 'help contains 2 variants' do
        expect(fifty_fifty.size).to eq(2)
      end

      it 'help contains correct variant' do
        expect(fifty_fifty).to include(game_question.correct_answer_key)
      end
    end
  end
end
