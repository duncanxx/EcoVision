import os
import io
import base64
import json
from PIL import Image
from ultralytics import YOLO
import logging
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


# 1. Load YOLO model
def model_fn(model_dir):
    logger.info("Loading Model.")
    model_path = os.path.join(model_dir, "last.pt")
    model = YOLO(model_path)
    logger.info("Model loaded.")
    return model


# 2. Input handling
def input_fn(request_body, content_type="application/json"):
    if content_type == "application/json":
        data = json.loads(request_body)
        if "image" in data:
            image_bytes = base64.b64decode(data["image"])
            return Image.open(io.BytesIO(image_bytes)).convert("RGB")
        else:
            raise ValueError("Missing 'image' field in JSON input")
    elif content_type == "application/octet-stream":
        return Image.open(io.BytesIO(request_body)).convert("RGB")
    else:
        raise ValueError(f"Unsupported content type: {content_type}")


# 3. Run prediction and draw bounding boxes
def predict_fn(input_data, model):
    logger.info("Starting inference...")
    results = model(input_data)
    logger.info("Inference finished...")

    detections = []
    annotated_image = None

    for r in results:
        boxes = r.boxes
        for box in boxes:
            detections.append({
                "class": model.names[int(box.cls)],
                "confidence": float(box.conf),
                "bbox": [float(x) for x in box.xyxy[0].tolist()]
            })

        # Get annotated image with bounding boxes
        annotated_image = r.plot()  # returns numpy array (BGR)

    return detections, annotated_image


# 4. Format output
def output_fn(prediction, accept="application/json"):
    detections, annotated_image = prediction

    if accept == "application/json":
        return json.dumps({"predictions": detections})

    elif accept == "image/jpeg":

        # Convert numpy BGR -> RGB
        annotated_image = annotated_image[:, :, ::-1]
        img = Image.fromarray(annotated_image)

        buf = io.BytesIO()
        img.save(buf, format="JPEG")
        return buf.getvalue()

    elif accept == "application/jsonlines":  # custom: JSON + image

        annotated_image = annotated_image[:, :, ::-1]
        img = Image.fromarray(annotated_image)
        buf = io.BytesIO()
        img.save(buf, format="JPEG")

        # Base64 encode image
        img_base64 = base64.b64encode(buf.getvalue()).decode("utf-8")

        return json.dumps({
            "predictions": detections,
            "image_base64": img_base64
        })

    else:
        raise ValueError(f"Unsupported accept type: {accept}")