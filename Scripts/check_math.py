#!/usr/bin/env python3
"""Verificador independente dos fixtures, com Decimal de alta precisão.
Não compila nem executa o motor Swift.
"""
import json
import random
from decimal import Decimal as D, localcontext, ROUND_HALF_UP
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "Packages/DecisionCore/Tests/DecisionCoreTests/Fixtures/cases.json"


def pv(flows, rate):
    rate = D(str(rate))
    assert rate > -1
    with localcontext() as context:
        context.prec = 50
        return sum(
            (D(flow["amount"]) / (1 + rate) ** (D(flow["day"]) / 30)
             for flow in flows),
            D(0),
        )


def schedule(total, n):
    total = D(str(total))
    unit = (total / n).quantize(D(".01"), rounding=ROUND_HALF_UP)
    return [unit] * (n - 1) + [total - unit * (n - 1)]


def check():
    fixtures = json.loads(FIXTURES.read_text())
    for case in fixtures:
        actual = pv(case["flows"], case["rate"])
        expected = D(str(case["expectedPV"]))
        assert abs(actual - expected) < D(".000001"), (case["id"], actual, expected)

    # Identidades e propriedades que não dependem dos valores gravados.
    assert pv([{"amount": "1000", "day": 0}], ".008") == 1000
    assert pv([{"amount": "100", "day": 90}], "0") == 100
    assert schedule("100", 3) == [D("33.33"), D("33.33"), D("33.34")]
    assert D("1000") / D("2.50") * D("20") / 1000 == D("8")

    with localcontext() as context:
        context.prec = 50
        for n in (1, 3, 6, 10, 12, 24):
            r = D(".008")
            flows = [{"amount": "100", "day": 30 * i} for i in range(1, n + 1)]
            closed_form = 100 * (1 - (1 + r) ** -n) / r
            assert abs(pv(flows, r) - closed_form) < D("1e-40")

    # Pagamentos positivos: maior rendimento ou prazo reduz o valor presente.
    rng = random.Random(20261012)
    for _ in range(250):
        amount = D(rng.randrange(10000, 10000000)) / 100
        n = rng.randrange(1, 37)
        parts = schedule(amount, n)
        assert sum(parts) == amount and min(parts) >= 0
        flows = [{"amount": str(value), "day": (i + 1) * 30} for i, value in enumerate(parts)]
        assert 0 < pv(flows, ".02") < pv(flows, ".005") < amount
        later = [{**flow, "day": flow["day"] + 30} for flow in flows]
        assert pv(later, ".005") < pv(flows, ".005")

    print(f"OK: {len(fixtures)} fixtures, identidades e 250 cronogramas aleatórios.")
    print("Verificação matemática de referência; Swift/Xcode ainda exigem validação no Mac.")


if __name__ == "__main__":
    check()
