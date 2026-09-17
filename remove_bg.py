from PIL import Image
import sys

def make_white_transparent(image_path, output_path, tolerance=30):
    try:
        img = Image.open(image_path)
        img = img.convert("RGBA")
        datas = img.getdata()
        
        newData = []
        for item in datas:
            # Check if pixel is close to white
            if item[0] > (255 - tolerance) and item[1] > (255 - tolerance) and item[2] > (255 - tolerance):
                # Replace with transparent
                newData.append((255, 255, 255, 0))
            else:
                newData.append(item)
                
        img.putdata(newData)
        img.save(output_path, "PNG")
        print(f"Success: {output_path}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    make_white_transparent(
        r"C:\Users\lefia\.gemini\antigravity\brain\08cbf076-2655-4324-9d0d-43971e77078a\modern_pos_icon_only_1789343050236.jpg", 
        "assets/images/logo.png",
        tolerance=15
    )
