# (c) goodprogrammer.ru

require 'rails_helper'
require 'support/my_spec_helper' # наш собственный класс с вспомогательными методами

# Тестовый сценарий для игрового контроллера
# Самые важные здесь тесты:
#   1. на авторизацию (чтобы к чужим юзерам не утекли не их данные)
#   2. на четкое выполнение самых важных сценариев (требований) приложения
#   3. на передачу граничных/неправильных данных в попытке сломать контроллер
#
RSpec.describe GamesController, type: :controller do
  # обычный пользователь
  let(:user) { FactoryBot.create(:user) }
  # админ
  let(:admin) { FactoryBot.create(:user, is_admin: true) }
  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryBot.create(:game_with_questions, user: user) }

  describe '#show' do
    context 'when authorizated user' do
      context 'when user watch self game' do
        before do
          sign_in(user)
          get :show, id: game_w_questions.id
        end

        it 'not finishes game' do
          game = assigns(:game)
          expect(game.finished?).to be false
        end

        it 'equals game user to user' do
          game = assigns(:game)
          expect(game.user).to eq(user)
        end

        it 'returns status 200' do
          expect(response.status).to eq(200)
        end

        it 'renders show template' do
          expect(response).to render_template('show')
        end
      end

      context 'when user try watch another user game' do
        let(:another_user) { FactoryBot.create(:user) }

        before do
          sign_in(another_user)
          get :show, id: game_w_questions.id
        end

        it 'returns status 302' do
          expect(response.status).to eq(302)
        end

        it 'redirects to root' do
          expect(response).to redirect_to(root_path)
        end

        it 'shows alert' do
          expect(flash[:alert]).to be
        end
      end
    end

    context 'when anonymous user' do
      context 'when user try watch game' do
        before { get :show, id: game_w_questions.id }

        it 'returns status 302' do
          expect(response.status).to eq(302)
        end

        it 'redirects to sign in' do
          expect(response).to redirect_to(new_user_session_path)
        end

        it 'shows alert' do
          expect(flash[:alert]).to be
        end
      end
    end
  end

  describe '#take_money' do
    context 'when authorizated user' do
      context 'when user take money before game finish' do
        let(:level) { 5 }

        before do
          sign_in(user)
          game_w_questions.update(current_level: level)

          put :take_money, id: game_w_questions.id
        end

        it 'redirects to user' do
          expect(response).to redirect_to(user_path)
        end

        it 'returns status 302' do
          expect(response.status).to eq(302)
        end

        it 'shows alert' do
          expect(flash[:warning]).to be
        end

        it 'game finished? returns true' do
          game = assigns(:game)

          expect(game.finished?).to be true
        end

        it 'game prize increase' do
          game = assigns(:game)

          expect(game.prize).to eq(Game::PRIZES[level - 1])
        end

        it 'user balance increase' do
          user.reload

          expect(user.balance).to eq(Game::PRIZES[level - 1])
        end
      end
    end

    context 'when anonymous user' do
      context 'when user take money before game finish' do
        let(:level) { 5 }

        before do
          game_w_questions.update(current_level: level)
          put :take_money, id: game_w_questions.id
        end

        it 'returns status 302' do
          expect(response.status).to eq(302)
        end

        it 'redirects to sign in' do
          expect(response).to redirect_to(new_user_session_path)
        end

        it 'shows alert' do
          expect(flash[:alert]).to be
        end
      end
    end
  end

  describe '#create' do
    context 'when authorizated user' do
      context 'when user start new game' do
        before do
          sign_in(user)
          generate_questions(15)
          post :create
        end

        it 'not finishes game' do
          game = assigns(:game)
          expect(game.finished?).to be false
        end

        it 'equals game user to user' do
          game = assigns(:game)
          expect(game.user).to eq(user)
        end

        it 'redirects to game' do
          game = assigns(:game)
          expect(response).to redirect_to(game_path(game))
        end

        it 'shows notice' do
          expect(flash[:notice]).to be
        end
      end

      context 'when user try start second game but not finished first' do
        before do
          sign_in(user)
          game_w_questions

          post :create
        end

        it 'first game exist' do
          expect(game_w_questions).to be
        end

        it 'not create second game' do
          expect(user.games[1]).to be nil
        end

        it 'returns status 302' do
          expect(response.status).to eq(302)
        end

        it 'redirects to first game' do
          expect(response).to redirect_to(game_path(game_w_questions))
        end

        it 'shows alert' do
          expect(flash[:alert]).to be
        end
      end
    end

    context 'when anonymous user' do
      context 'when user start new game' do
        before do
          generate_questions(15)
          post :create
        end

        it 'returns status 302' do
          expect(response.status).to eq(302)
        end

        it 'redirects to sign in' do
          expect(response).to redirect_to(new_user_session_path)
        end

        it 'shows alert' do
          expect(flash[:alert]).to be
        end
      end
    end
  end

  describe '#answer' do
    context 'when authorizated user' do
      context 'when user answer correct' do
        before do
          sign_in(user)
          put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key
        end

        it 'not finishes game' do
          game = assigns(:game)
          expect(game.finished?).to be false
        end

        it 'moves to next level' do
          game = assigns(:game)
          expect(game.current_level).to be > 0
        end

        it 'redirects to game' do
          game = assigns(:game)
          expect(response).to redirect_to(game_path(game))
        end

        it 'not shows flash' do
          expect(flash.empty?).to be true
        end
      end

      context 'when user answer wrong' do
        before do
          sign_in(user)
          put :answer, id: game_w_questions.id, letter: 'c'
        end

        it 'returns status 302' do
          expect(response.status).to eq(302)
        end

        it 'redirects to user' do
          expect(response).to redirect_to(user_path(user))
        end

        it 'shows alert' do
          expect(flash[:alert]).to be
        end

        it 'finishes game' do
          game = assigns(:game)

          expect(game.finished?).to be true
        end

        it 'failes game' do
          game = assigns(:game)

          expect(game.is_failed?).to be true
        end

        it 'returns :fail game status' do
          game = assigns(:game)

          expect(game.status).to be(:fail)
        end

        it 'not increase user balance' do
          user.reload
          expect(user.balance).to eq(0)
        end
      end
    end

    context 'when anonymous user' do
      context 'when user try answer' do
        before do
          put :answer, id: game_w_questions.id,
            letter: game_w_questions.current_game_question.correct_answer_key
        end

        it 'returns status 302' do
          expect(response.status).to eq(302)
        end

        it 'redirects to sign in' do
          expect(response).to redirect_to(new_user_session_path)
        end

        it 'shows alert' do
          expect(flash[:alert]).to be
        end
      end
    end
  end

  describe '#help' do
    context 'when authorizated user' do
      context 'when user take audience_help' do
        context 'before take help' do
          it 'returns audience help hash empty before user take help' do
            expect(game_w_questions.current_game_question.help_hash[:audience_help]).not_to be
          end

          it 'not uses audience help before user take help' do
            expect(game_w_questions.audience_help_used).to be false
          end
        end

        context 'after take help' do
          before do
            sign_in(user)
            put :help, id: game_w_questions.id, help_type: :audience_help
          end

          it 'not finishes game' do
            game = assigns(:game)
            expect(game.finished?).to be false
          end

          it 'uses audience_help' do
            game = assigns(:game)
            expect(game.audience_help_used).to be true
          end

          it 'fills audience_help hash' do
            game = assigns(:game)
            expect(game.current_game_question.help_hash[:audience_help]).to be
          end

          it 'returns letters from audience_help hash' do
            game = assigns(:game)
            expect(game.current_game_question.help_hash[:audience_help].keys).to contain_exactly('a', 'b', 'c', 'd')
          end

          it 'redirects to game' do
            game = assigns(:game)
            expect(response).to redirect_to(game_path(game))
          end
        end
      end

      context 'when user take fifty_fifty' do
        context 'before take help' do
          it 'returns fifty_fifty hash empty' do
            expect(game_w_questions.current_game_question.help_hash[:fifty_fifty]).not_to be
          end

          it 'not uses fifty_fifty' do
            expect(game_w_questions.fifty_fifty_used).to be false
          end
        end

        context 'after take help' do
          before do
            sign_in(user)
            put :help, id: game_w_questions.id, help_type: :fifty_fifty
          end

          it 'not finishes game' do
            game = assigns(:game)
            expect(game.finished?).to be false
          end

          it 'uses fifty_fifty' do
            game = assigns(:game)
            expect(game.fifty_fifty_used).to be true
          end

          it 'fills fifty_fifty array' do
            game = assigns(:game)
            expect(game.current_game_question.help_hash[:fifty_fifty]).to be
          end

          it 'returns 2 variants from fifty_fifty array' do
            game = assigns(:game)
            expect(game.current_game_question.help_hash[:fifty_fifty].size).to eq(2)
          end

          it 'contains 1 correct variant' do
            game = assigns(:game)
            correct_answer_key = game.current_game_question.correct_answer_key
            expect(game.current_game_question.help_hash[:fifty_fifty]).to include(correct_answer_key)
          end

          it 'redirects to game' do
            game = assigns(:game)
            expect(response).to redirect_to(game_path(game))
          end
        end
      end
    end

    context 'when anonymous user' do
      context 'when user take audience_help' do
        before { put :help, id: game_w_questions.id, help_type: :audience_help }

        it 'returns status 302' do
          expect(response.status).to eq(302)
        end

        it 'redirects to sign in' do
          expect(response).to redirect_to(new_user_session_path)
        end

        it 'shows alert' do
          expect(flash[:alert]).to be
        end
      end
    end
  end
end
