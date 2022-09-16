# (c) goodprogrammer.ru

require 'rails_helper'
require 'support/my_spec_helper' # наш собственный класс с вспомогательными методами

# Тестовый сценарий для модели Игры
# В идеале - все методы должны быть покрыты тестами,
# в этом классе содержится ключевая логика игры и значит работы сайта.
RSpec.describe Game, type: :model do
  # пользователь для создания игр
  let(:user) { FactoryBot.create(:user) }

  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryBot.create(:game_with_questions, user: user) }

  # Группа тестов на работу фабрики создания новых игр
  context 'Game Factory' do
    it 'Game.create_game! new correct game' do
      # генерим 60 вопросов с 4х запасом по полю level,
      # чтобы проверить работу RANDOM при создании игры
      generate_questions(60)

      game = nil
      # создaли игру, обернули в блок, на который накладываем проверки
      expect {
        game = Game.create_game_for_user!(user)
      }.to change(Game, :count).by(1).and(# проверка: Game.count изменился на 1 (создали в базе 1 игру)
        change(GameQuestion, :count).by(15).and(# GameQuestion.count +15
          change(Question, :count).by(0) # Game.count не должен измениться
        )
      )
      # проверяем статус и поля
      expect(game.user).to eq(user)
      expect(game.status).to eq(:in_progress)
      # проверяем корректность массива игровых вопросов
      expect(game.game_questions.size).to eq(15)
      expect(game.game_questions.map(&:level)).to eq (0..14).to_a
    end
  end


  # тесты на основную игровую логику
  context 'game mechanics' do

    # правильный ответ должен продолжать игру
    it 'answer correct continues game' do
      # текущий уровень игры и статус
      level = game_w_questions.current_level
      q = game_w_questions.current_game_question
      expect(game_w_questions.status).to eq(:in_progress)

      game_w_questions.answer_current_question!(q.correct_answer_key)

      # перешли на след. уровень
      expect(game_w_questions.current_level).to eq(level + 1)
      # ранее текущий вопрос стал предыдущим
      expect(game_w_questions.previous_game_question).to eq(q)
      expect(game_w_questions.current_game_question).not_to eq(q)
      # игра продолжается
      expect(game_w_questions.status).to eq(:in_progress)
      expect(game_w_questions.finished?).to be_falsey
    end

    it 'take_money! finish the game' do
      letter = game_w_questions.current_game_question.correct_answer_key
      game_w_questions.answer_current_question!(letter)

      game_w_questions.take_money!
      prize = game_w_questions.prize

      expect(prize).to be > 0
      expect(game_w_questions.status).to be(:money)
      expect(game_w_questions.finished?).to be_truthy
      expect(user.balance).to eq(prize)
    end
  end

  describe '#status' do
    before(:each) do
      game_w_questions.finished_at = Time.now
    end

    it 'status game fail' do
      game_w_questions.is_failed = true
      expect(game_w_questions.status).to be(:fail)
    end

    it 'status game timeout' do
      game_w_questions.created_at -= Game::TIME_LIMIT + 10
      game_w_questions.is_failed = true
      expect(game_w_questions.status).to be(:timeout)
    end

    it 'status game won' do
      game_w_questions.current_level = Question::QUESTION_LEVELS.last + 1
      expect(game_w_questions.status).to be(:won)
    end

    it 'status game money' do
      expect(game_w_questions.status).to be(:money)
    end

    it 'status game in progress' do
      game_w_questions.finished_at = nil
      expect(game_w_questions.status).to be(:in_progress)
    end
  end

  describe '#current_game_question' do
    it 'returns GameQuestion class' do
      expect(game_w_questions.current_game_question).to be_kind_of(GameQuestion)
    end

    it 'is first question when game starts' do
      first_question = game_w_questions.game_questions.first
      expect(game_w_questions.current_game_question).to eq(first_question)
    end
  end

  describe '#previous_level' do
    it 'returns number previous level' do
      expect(game_w_questions.previous_level).to eq(-1)
    end
  end

  describe '#answer_current_question!' do
    let(:q) { game_w_questions.current_game_question }
    let(:game) { game_w_questions }

    context 'when answer is correct' do
      before(:each) do
        game.answer_current_question!(q.correct_answer_key)
      end

      it 'returns true' do
        expect(game.answer_current_question!(q.correct_answer_key)).to be true
      end

      it 'returns :in_progress status' do
        expect(game.status).to be(:in_progress)
      end

      it 'game switch to next level' do
        expect(game.current_level).to eq(1)
      end

      context 'and question is last' do
        before(:each) do
          game.current_level = Question::QUESTION_LEVELS.last
          game.answer_current_question!(q.correct_answer_key)
        end

        it 'game finished' do
          expect(game.finished?).to be true
        end

        it 'returns :won status' do
          expect(game.status).to be(:won)
        end

        it 'game has max prize' do
          expect(game.prize).to eq(Game::PRIZES.last)
        end

        it 'prize add to user balance' do
          expect(user.balance).to eq(game.prize)
        end
      end
    end

    context 'when answer is not correct' do
      before(:each) do
        game.answer_current_question!('c')
      end

      it 'game finished' do
        expect(game.finished?).to be true
      end

      it 'returns :fail status' do
        expect(game.status).to be(:fail)
      end

      it 'is_failed returns true' do
        expect(game.is_failed).to be true
      end

      it 'add finished_at time' do
        expect(game.finished_at).to be_truthy
      end

      it 'user balance not increase' do
        expect(user.balance).to eq(0)
      end
    end

    context 'when user try answer after timeout' do
      before(:each) do
        game.created_at -= Game::TIME_LIMIT + 10
        game.time_out!
      end

      it 'returns :timeout status' do
        expect(game.status).to be(:timeout) 
      end

      it 'returns false' do
        expect(game.answer_current_question!(q.correct_answer_key)).to be_falsey
      end

      it 'game finished' do
        expect(game.finished?).to be_truthy
      end
    end
  end
end
