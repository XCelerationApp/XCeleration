# Release rehearsal (real phones)

Run this on the **TestFlight build** before every App Store submission, and
again after any change to sharing, encoding, sync or saving. The simulator
cannot share between phones, scan QR codes or run voice entry properly, so
these only get tested here.

You need three phones (Coach, Timer, Bib Recorder), about 20 minutes, and a
Google account that is **not** the developer's. Tick each line; write down
anything odd, even if it worked in the end.

## Before the race

- [ ] Install the TestFlight build on all three phones. Note the build number.
- [ ] Coach: create a race and add runners from a spreadsheet split into boys'
      and girls' teams. Untick one team under **Add to this race**; only the
      ticked team is in the race, and the other is saved.
- [ ] Bib Recorder: open voice entry once on Wi-Fi so the speech model
      downloads.

## Sending the race

- [ ] Open **Get Race from Coach** on the Timer, wait a full minute, then tap
      **Send to Volunteers** on the coach. The Timer gets the race.
- [ ] The Bib Recorder gets the race at the same time as the Timer.
- [ ] Tap **Send to Volunteers** again from the race; both phones get it again
      without being asked (nothing is recorded yet).
- [ ] Timer: scan the coach's QR code instead of wireless. The race opens.
- [ ] Let one phone time out (10 minutes, or leave it and come back), tap
      **Try again**, and it connects.
- [ ] Walk one phone away mid-send and back; it finishes on its own.

## The race

- [ ] Timer: start the race, log about 15 finishes, tap **Counts differ?**
      → **Missed one** once and **Extra tap** once.
- [ ] Bib Recorder: record bibs by voice, and one wrong bib on purpose.
- [ ] Lock and unlock a phone mid-race; nothing is lost.
- [ ] Coach: add a runner, then **Send to Volunteers** again. The Bib
      Recorder asks **Update race** or **Make a copy** and says "1 runner:
      1 added". **Update race** keeps every bib; the Timer, asked the same,
      keeps every time.
- [ ] Coach: rename the race and send it again. Both phones ask **Is this
      the same race?**; **Same race** keeps what was recorded under the new
      name.

## Results

- [ ] Coach: **Collect Results** from both phones wirelessly, then again by
      QR code from the Timer.
- [ ] Resolve the missed runner, the extra tap and the wrong bib; the tips
      under **How to decide** name the right places.
- [ ] Save, then fix one result with **Edit** on the Results tab.
- [ ] **Share Results**: PDF, and **Google Sheets** signed in with the
      non-developer Google account. The sheet opens with the results.
- [ ] Send the results to a spectator's phone.

## Clean-up and other

- [ ] Timer and Bib Recorder: delete the race. The practice race (or another
      race) opens, never an empty screen.
- [ ] Settings: Privacy Policy, Terms and Support links open the website.
- [ ] Check Sentry for new issues from the rehearsal before submitting.

If anything fails, fix it and run the affected section again on the next
build. Record the build number and date here when a full run passes:

| Build | Date | Who | Notes |
| --- | --- | --- | --- |
|  |  |  |  |
