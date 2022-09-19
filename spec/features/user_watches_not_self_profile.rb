require 'rails_helper'

RSpec.feature 'USER watches not self phofile', type: :feature do
  let(:user) { FactoryBot.create :user }
  let(:another_user) { FactoryBot.create :user }
  let!(:games) do
    [FactoryBot.create(:game, user: another_user, created_at: Time.parse('2022-09-19 19:00 +0300'),
      finished_at: Time.parse('2022-09-19 19:20 +0300'), current_level: 7, prize: 4000),
    FactoryBot.create(:game, user: another_user, created_at: Time.parse('2022-09-19 19:30 +0300'),
      current_level: 4)]
  end

  before { login_as(user) }

  scenario 'successfully' do
    visit "users/#{another_user.id}"

    expect(page).to have_current_path "/users/#{another_user.id}"

    expect(page).not_to have_content 'Сменить имя и пароль'

    expect(page).to have_content '2'
    expect(page).to have_content 'в процессе'
    expect(page).to have_content '19 сент., 19:30'
    expect(page).to have_content '4'
    expect(page).to have_content '0'

    expect(page).to have_content '1'
    expect(page).to have_content 'деньги'
    expect(page).to have_content '19 сент., 19:00'
    expect(page).to have_content '7'
    expect(page).to have_content '4 000 ₽'
  end
end
