require 'rails_helper'

RSpec.describe 'users/show', type: :view do
  let(:user) { FactoryBot.build_stubbed(:user, name: 'Ian Curtis') }

  before do
    assign(:user, user)
    assign(:games, stub_template('users/_game.html.erb' => 'User games goes here'))

    render
  end

  it 'renders user name' do
    expect(rendered).to match 'Ian Curtis'
  end

  it 'renders template with user games' do
    expect(rendered).to match 'User games goes here'
  end

  context 'when user want to change password' do
    context 'and user authorizated' do 
      before do
        allow(view).to receive(:current_user).and_return(user)
        render
      end

      it 'renders change password button' do
        expect(rendered).to match 'Сменить имя и пароль'
      end
    end

    context 'and user anonymous' do
      it 'not renders change password button' do
        expect(rendered).not_to match 'Сменить имя и пароль'
      end
    end
  end
end
