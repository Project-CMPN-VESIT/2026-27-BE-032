import sys
sys.path.append(r"c:\Capstone Project\option2")

from backend.models.registry import ModelRegistry
from backend.services.prediction_service import predict_retina, predict_foot, predict_final

def main():
    registry = ModelRegistry()
    registry.load_all()

    ret_res = predict_retina(r"c:\Capstone Project\option2\test_retina.jpg", model=registry.retina_model)
    foot_res = predict_foot(r"c:\Capstone Project\option2\test_foot.jpg", model=registry.foot_model)

    print("\n" + "="*50)
    print("RETINA PREDICTION :", ret_res["prediction"])
    print("RETINA RISK %     :", ret_res["risk_percentage"])
    print("RETINA SEVERITY   :", ret_res["severity"])
    print("RETINA CONFIDENCE :", ret_res["confidence"])

    print("\nFOOT PREDICTION   :", foot_res["prediction"])
    print("FOOT RISK %       :", foot_res["risk_percentage"])
    print("FOOT SEVERITY     :", foot_res["severity"])
    print("FOOT CONFIDENCE   :", foot_res["confidence"])

    assessment_res = {"risk_percentage": 60.0}
    final_res = predict_final(assessment_res, ret_res, foot_res)

    print("\nOVERALL RISK %    :", final_res["overall_risk_percentage"])
    print("FINAL PREDICTION  :", final_res["prediction_label"])
    print("RISK LEVEL        :", final_res["risk_level"])
    print("="*50)

if __name__ == "__main__":
    main()
